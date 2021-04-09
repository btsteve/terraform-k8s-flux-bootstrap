
resource "tls_private_key" "ssh" {
  count = var.flux_auth_type == "ssh" && var.flux_ssh_key.auto_generate_key ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = "2048"
}

resource "null_resource" "ssh_scan" {
  count = var.flux_auth_type == "ssh" ? 1 : 0

  triggers = {
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "ssh-keyscan ${var.flux_ssh_scan_url} > /tmp/known_hosts"
  }
}

data "local_file" "known_hosts" {
  depends_on = [null_resource.ssh_scan]
  count      = var.flux_auth_type == "ssh" ? 1 : 0

  filename = "/tmp/known_hosts"
}

resource "kubernetes_secret" "basic" {
  count      = var.flux_auth_type == "basic" ? 1 : 0
  depends_on = [kubectl_manifest.apply]

  metadata {
    name      = data.flux_sync.main.name
    namespace = data.flux_sync.main.namespace
  }

  data = {
    username = var.flux_basic_auth.username
    password = var.flux_basic_auth.password
  }
}

resource "kubernetes_secret" "ssh" {
  count      = var.flux_auth_type == "ssh" ? 1 : 0
  depends_on = [kubectl_manifest.apply]

  metadata {
    name      = data.flux_sync.main.name
    namespace = data.flux_sync.main.namespace
  }

  data = {
    "identity"     = var.flux_auth_type == "ssh" && var.flux_ssh_key.auto_generate_key ? tls_private_key.ssh.0.private_key_pem : var.flux_ssh_key.private_key
    "identity.pub" = var.flux_auth_type == "ssh" && var.flux_ssh_key.auto_generate_key ? tls_private_key.ssh.0.public_key_openssh : var.flux_ssh_key.public_key
    "known_hosts"  = data.local_file.known_hosts.0.content
  }
}
