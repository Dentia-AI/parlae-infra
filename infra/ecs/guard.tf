resource "terraform_data" "prod_destroy_guard" {
  count = local.protect_resources ? 1 : 0
  input = "prod-destroy-guard"

  lifecycle {
    prevent_destroy = true
  }
}
