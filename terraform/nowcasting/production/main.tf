/*====
Variables used across all modules
======*/
locals {
  production_availability_zones = ["${var.region}a", "${var.region}b", "${var.region}c"]
  domain = "nowcasting"
  modules_url = "github.com/openclimatefix/ocf-infrastructure//terraform/modules"
}


module "networking" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/networking?ref=eac7811"
  region               = var.region
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnets_cidr  = var.public_subnets_cidr
  private_subnets_cidr = var.private_subnets_cidr
  availability_zones   = local.production_availability_zones
}

module "ec2-bastion" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/networking/ec2_bastion?ref=eac7811"

  region               = var.region
  vpc_id               = module.networking.vpc_id
  public_subnets_id    = module.networking.public_subnets[0].id
}

module "s3" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/storage/s3-trio?ref=eac7811"

  region      = var.region
  environment = var.environment

}

module "ecs" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/ecs?ref=eac7811"
  region      = var.region
  environment = var.environment
  domain = local.domain
}

module "forecasting_models_bucket" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/storage/s3-private?ref=eac7811"

  region              = var.region
  environment         = var.environment
  service_name        = "national-forecaster-models"
  domain              = local.domain
  lifecycled_prefixes = []
}

module "api" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/api?ref=eac7811"

  region                              = var.region
  environment                         = var.environment
  vpc_id                              = module.networking.vpc_id
  subnets                             = module.networking.public_subnets
  docker_version                      = var.api_version
  database_forecast_secret_url        = module.database.forecast-database-secret-url
  database_pv_secret_url              = module.database.pv-database-secret-url
  iam-policy-rds-forecast-read-secret = module.database.iam-policy-forecast-db-read
  iam-policy-rds-pv-read-secret       = module.database.iam-policy-pv-db-read
  auth_domain = var.auth_domain
  auth_api_audience = var.auth_api_audience
  n_history_days = "2"
  adjust_limit = 1000.0
  sentry_dsn = var.sentry_dsn
}


module "database" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/storage/database-pair?ref=eac7811"

  region          = var.region
  environment     = var.environment
  db_subnet_group = module.networking.private_subnet_group
  vpc_id          = module.networking.vpc_id
}

module "nwp" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/nwp?ref=eac7811"

  region                  = var.region
  environment             = var.environment
  iam-policy-s3-nwp-write = module.s3.iam-policy-s3-nwp-write
  ecs-cluster             = module.ecs.ecs_cluster
  public_subnet_ids       = [module.networking.public_subnets[0].id]
  docker_version          = var.nwp_version
  database_secret         = module.database.forecast-database-secret
  iam-policy-rds-read-secret = module.database.iam-policy-forecast-db-read
  consumer-name = "nwp"
  s3_config = {
    bucket_id = module.s3.s3-nwp-bucket.id
    savedir_data = "data"
    savedir_raw = "raw"
  }
}

module "nwp-national" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/nwp?ref=eac7811"

  region                  = var.region
  environment             = var.environment
  iam-policy-s3-nwp-write = module.s3.iam-policy-s3-nwp-write
  ecs-cluster             = module.ecs.ecs_cluster
  public_subnet_ids       = [module.networking.public_subnets[0].id]
  docker_version          = var.nwp_version
  database_secret         = module.database.forecast-database-secret
  iam-policy-rds-read-secret = module.database.iam-policy-forecast-db-read
  consumer-name = "nwp-national"
  s3_config = {
    bucket_id = module.s3.s3-nwp-bucket.id
    savedir_data = "data-national"
    savedir_raw = "raw-national"
  }
}

module "sat" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/sat?ref=eac7811"

  region                  = var.region
  environment             = var.environment
  iam-policy-s3-sat-write = module.s3.iam-policy-s3-sat-write
  s3-bucket               = module.s3.s3-sat-bucket
  ecs-cluster             = module.ecs.ecs_cluster
  public_subnet_ids       = [module.networking.public_subnets[0].id]
  docker_version          = var.sat_version
  database_secret         = module.database.forecast-database-secret
  iam-policy-rds-read-secret = module.database.iam-policy-forecast-db-read
}


module "pv" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/pv?ref=eac7811"

  region                  = var.region
  environment             = var.environment
  ecs-cluster             = module.ecs.ecs_cluster
  public_subnet_ids       = [module.networking.public_subnets[0].id]
  database_secret         = module.database.pv-database-secret
  database_secret_forecast = module.database.forecast-database-secret
  docker_version          = var.pv_version
  docker_version_ss          = var.pv_ss_version
  iam-policy-rds-read-secret = module.database.iam-policy-pv-db-read
  iam-policy-rds-read-secret_forecast = module.database.iam-policy-forecast-db-read
}

module "gsp" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/gsp?ref=eac7811"

  region                  = var.region
  environment             = var.environment
  ecs-cluster             = module.ecs.ecs_cluster
  public_subnet_ids       = [module.networking.public_subnets[0].id]
  database_secret         = module.database.forecast-database-secret
  docker_version          = var.gsp_version
  iam-policy-rds-read-secret = module.database.iam-policy-forecast-db-read
}

module "metrics" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/metrics?ref=eac7811"

  region                  = var.region
  environment             = var.environment
  ecs-cluster             = module.ecs.ecs_cluster
  public_subnet_ids       = [module.networking.public_subnets[0].id]
  database_secret         = module.database.forecast-database-secret
  docker_version          = var.metrics_version
  iam-policy-rds-read-secret = module.database.iam-policy-forecast-db-read
}


module "forecast" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/forecast?ref=eac7811"

  region                        = var.region
  environment                   = var.environment
  ecs-cluster                   = module.ecs.ecs_cluster
  subnet_ids                    = [module.networking.public_subnets[0].id]
  iam-policy-rds-read-secret    = module.database.iam-policy-forecast-db-read
  iam-policy-rds-pv-read-secret = module.database.iam-policy-pv-db-read
  iam-policy-s3-nwp-read        = module.s3.iam-policy-s3-nwp-read
  iam-policy-s3-sat-read        = module.s3.iam-policy-s3-sat-read
  iam-policy-s3-ml-read         = module.s3.iam-policy-s3-ml-write #TODO update name
  database_secret               = module.database.forecast-database-secret
  pv_database_secret            = module.database.pv-database-secret
  docker_version                = var.forecast_version
  s3-nwp-bucket                 = module.s3.s3-nwp-bucket
  s3-sat-bucket                 = module.s3.s3-sat-bucket
  s3-ml-bucket                  = module.s3.s3-ml-bucket
}


module "national_forecast" {
  source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/forecast_generic?ref=eac7811"

  region      = var.region
  environment = var.environment
  app-name    = "forecast_national"
  ecs_config  = {
    docker_image   = "openclimatefix/gradboost_pv"
    docker_version = var.national_forecast_version
    memory_mb = 10240
    cpu = 2048
  }
  rds_config = {
    database_secret_arn             = module.database.forecast-database-secret.arn
    database_secret_read_policy_arn = module.database.iam-policy-forecast-db-read.arn
  }
  scheduler_config = {
    subnet_ids      = [module.networking.public_subnets[0].id]
    ecs_cluster_arn = module.ecs.ecs_cluster.arn
    cron_expression = "cron(15,45 * * * ? *)" # Every 10 minutes
  }
  s3_ml_bucket = {
    bucket_id              = module.forecasting_models_bucket.bucket.id
    bucket_read_policy_arn = module.forecasting_models_bucket.read-policy.arn
  }
  s3_nwp_bucket = {
    bucket_id = module.s3.s3-nwp-bucket.id
    bucket_read_policy_arn = module.s3.iam-policy-s3-nwp-read.arn
    datadir = "data-national"
  }
}

module "analysis_dashboard" {
    source = "github.com/openclimatefix/ocf-infrastructure//terraform/modules/services/internal_ui?ref=eac7811"

    region      = var.region
    environment = var.environment
    eb_app_name = "internal-ui"
    domain = local.domain
    docker_config = {
        image = "ghcr.io/openclimatefix/uk-analysis-dashboard"
        version = var.internal_ui_version
    }
    networking_config = {
        vpc_id = module.networking.vpc_id
        subnets = [module.networking.public_subnets[0].id]
    }
    database_config = {
        secret = module.database.forecast-database-secret-url
        read_policy_arn = module.database.iam-policy-forecast-db-read.arn
    }
}
