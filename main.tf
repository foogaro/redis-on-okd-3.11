terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.5.0"
    }
  }
}

variable "location" {
  type = map(any)
  default = {
    "project"     = "redisonokd"
    "region"      = "europe-west6"
    "zone"        = "europe-west6-a"
    "email"       = "redisonokd@redisonokd.iam.gserviceaccount.com"
    "credentials" = "redisonokd-1a14259a7e60.json"
    "scopes"      = "cloud-platform"
    "ssh-key"     = "/Users/foogaro/.ssh/redisonokd.pub"
  }
}

provider "google" {
  project     = var.location["project"]
  region      = var.location["region"]
  zone        = var.location["zone"]
  credentials = file(var.location["credentials"])
}

variable "network" {
  type = map(any)
  default = {
    "name"                    = "redisonokd"
    "auto_create_subnetworks" = "false"
    "routing_mode"            = "REGIONAL"
    "ip_cidr_range"           = "10.172.0.0/16"
  }
}

variable "server_template" {
  type = map(any)
  default = {
    "name"         = "redisonokd"
    "machine_type" = "e2-standard-8"
    "disk_type"    = "pd-standard"
    "disk_size"    = 40
    "image"        = "centos-7-v20210916"
  }
}

variable "server_list" {
  type    = list(any)
  default = ["master", "node1", "node2", "node3"]
}

variable "server_ips" {
  type = map(any)
  default = {
    "master" = "10.172.0.100"
    "node1"  = "10.172.0.110"
    "node2"  = "10.172.0.120"
    "node3"  = "10.172.0.130"
  }
}

variable "server_ext_ips" {
  type = map(any)
  default = {
    "master" = "34.65.169.238"
    "node1"  = ""
    "node2"  = ""
    "node3"  = ""
  }
}

variable "tags" {
  type    = list(any)
  default = ["http-server", "https-server", "redis-on-okd", "redis-on-okdocp"]
}

resource "google_compute_network" "default" {
  name                    = format("%s%s", var.network["name"], "-network")
  auto_create_subnetworks = var.network["auto_create_subnetworks"]
  routing_mode            = var.network["routing_mode"]
}

resource "google_compute_subnetwork" "default" {
  name          = format("%s%s", var.network["name"], "-subnetwork")
  ip_cidr_range = var.network["ip_cidr_range"]
  region        = var.location["region"]
  network       = google_compute_network.default.id
}

resource "google_compute_firewall" "ingress-allow-all" {
  name           = "ingress-allow-all"
  direction      = "INGRESS"
  disabled       = false
  enable_logging = false
  network        = google_compute_network.default.id
  priority       = 1000
  source_ranges  = ["0.0.0.0/0"]
  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "egress-allow-all" {
  name           = "egress-allow-all"
  direction      = "EGRESS"
  disabled       = false
  enable_logging = false
  network        = google_compute_network.default.id
  priority       = 1000
  allow {
    protocol = "all"
  }
}

resource "google_compute_instance" "vms" {


  for_each = toset(var.server_list)

  name         = format("%s-%s", var.server_template["name"], each.value)
  machine_type = var.server_template["machine_type"]
  tags         = var.tags
  metadata = {
    zone = var.location["zone"]
    ssh-keys = format("%s:%s", "foogaro", file(var.location["ssh-key"]))
  }

  service_account {
    email  = var.location["email"]
    scopes = [var.location["scopes"]]
  }

  boot_disk {
    initialize_params {
      image = var.server_template["image"]
      size  = var.server_template["disk_size"]
      type  = var.server_template["disk_type"]
    }
  }

  network_interface {
    network    = google_compute_network.default.id
    network_ip = var.server_ips[each.value]
    subnetwork = google_compute_subnetwork.default.id
    access_config {
      network_tier = "PREMIUM"
      nat_ip = var.server_ext_ips[each.value]
    }
  }

}
