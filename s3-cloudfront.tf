module "s3Primary" {
  source      = "./object"
  bucket_name = var.bucket_name
  source_file = "object/index.html"
}

module "cloud-front" {
  source       = "./cloud-front"
  s3_primary   = module.s3Primary.bucket_id
  nlb_dns_name = module.nlb.dns_name
  depends_on = [
    module.s3Primary,
    module.nlb
  ]
}

module "cdn-oac-bucket-policy-primary" {
  source         = "./cdn-oac"
  bucket_id      = module.s3Primary.bucket_id
  cloudfront_arn = module.cloud-front.cloudfront_arn
  bucket_arn     = module.s3Primary.bucket_arn
}

/*
module "cloudfront" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.0"  
}*/