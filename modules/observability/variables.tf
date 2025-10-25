variable "name_prefix" {
  type        = string
  description = "Prefix to be used for naming resources"
}

variable "tags" {
  type        = map(string)
  description = "Tags to be applied to all resources"
}
