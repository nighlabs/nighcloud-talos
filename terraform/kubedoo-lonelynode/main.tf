resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.node_data.controlplanes : k]
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  for_each                    = var.node_data.controlplanes
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/machine-config.yml.tmpl", {
      cluster_vip               = var.cluster_vip
      cluster_nameserver        = var.cluster_nameserver
      cluster_advertisedsubnets = var.cluster_advertisedsubnets
      install_disk              = each.value.install_disk
      hostname                  = each.value.hostname
      mainnet_iface             = each.value.mainnet_iface
      mainnet_ip                = each.value.mainnet_ip
      stornet_iface             = each.value.stornet_iface
      stornet_ip                = each.value.stornet_ip
      stornet_mtu               = var.stornet_mtu
    })
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
}

data "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.cluster_vip
  wait                 = true
}
