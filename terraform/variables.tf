variable "TagProject" {
  description = "Nome do projeto"
  type = string
  default = "dbt_project"
}

variable "TagEnv" {
  description = "Nome do ambiente"
  type = string
  default = "prd"
}

variable "GroupName" {
  description = "Nome do grupo de execucao DBT"
  type        = string
  default = "dbt_group"
}

variable "UserName" {
  description = "Nome usuario DBT"
  type = string
  default = "dbt_user"
}

variable "aws_region" {
  description = "Regiao AWS"
  type = string
  default = "us-east-1"
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}

variable "LambdaName" {
  description = "Nome da Lambda"
  type        = string
  default     = "dbt_init"
}

variable "EmailsSNS" {
  description = "Lista de Emails SNS para notificacao de erros do DBT"
  type        = list(string)
  default     = ["email1@dominio.com", "email2@dominio.com"]
}

variable "HourSchedule" {
  description = "Hora para iniciar o DBT"
  type        = string
  default     = "7"
}

variable "MinuteSchedule" {
  description = "Minuto para iniciar o DBT"
  type        = string
  default     = "0"
}

variable "TimeZone" {
  description = "Fuso horario"
  type        = string
  default     = "America/Sao_Paulo"
}

variable "github_oauth_token" {
  description = "Token GitHub"
  type        = string
  default = "seu_token"
}

variable "github_repositorio" {
  description = "Repositorio GitHub"
  type        = string
  default = "https://github.com/<seu-usuario>/<seu-repositorio>.git"
}