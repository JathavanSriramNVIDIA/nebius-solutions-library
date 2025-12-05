locals {
  active_checks_scopes = {
    # Scope for dev clusters
    dev = {
      dcgmiDiagR2 = {
        runAfterCreation = false
      }
      dcgmiDiagR3 = {
        runAfterCreation = false
      }
      sshCheck = {
        numOfLoginNodes = var.node_count.login
      }
    }

    # Run what is relevant in E2E
    testing = {
      dcgmiDiagR3 = {
        runAfterCreation = false
      }
      sshCheck = {
        numOfLoginNodes = var.node_count.login
      }
    }

    # Check the provisioned cluster, but don't run health-checks that take long
    prod_quick = {
      allReducePerfNCCLInDocker = {
        runAfterCreation = false
      }
      dcgmiDiagR2 = {
        runAfterCreation = false
      }
      dcgmiDiagR3 = {
        runAfterCreation = false
      }
      sshCheck = {
        numOfLoginNodes = var.node_count.login
      }
    }

    # Run all available health-checks
    prod_acceptance = {
      allReducePerfNCCLInDocker = {
        runAfterCreation = false
      }
      sshCheck = {
        numOfLoginNodes = var.node_count.login
      }
    }
  }

  soperator_activechecks_override_yaml = yamlencode(local.active_checks_scopes[var.active_checks_scope])
}
