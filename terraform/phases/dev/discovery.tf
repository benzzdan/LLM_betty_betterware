resource "aws_service_discovery_private_dns_namespace" "payroll_guru" {
  name = "payrollguru.com"
  description = "Dominio para todos los servicios"
  vpc = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "llm_service" {
  name = "llm-service"
  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.payroll_guru.id}"
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl = 10
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 5
  }
}

resource "aws_service_discovery_service" "client_service" {
  name = "client-service"
  dns_config {
    namespace_id = "${aws_service_discovery_private_dns_namespace.payroll_guru.id}"
    routing_policy = "MULTIVALUE"
    dns_records {
      ttl = 60
      type = "A"
    }
  }
  health_check_custom_config {
    failure_threshold = 5
  }
}