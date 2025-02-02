--- 
title: "Controlling a Proxmox VM with Python"
date: "2023-02-25"
author: "Mark"
tags: ["python", "discord", "proxmox"]
keywords: ["python", "discord", "proxmox"]
description: "Using Proxmoxer library to control a Proxmox QEMU VM"
showFullContent: false
draft: false
summary: "Creating a Discord bot to control a Proxmox QEMU VM"
---

# Hi 👋

Recently I was wanting to control a Proxmox VM in my home lab via discord. 

There's a good library available for Python called [Promoxer](https://proxmoxer.github.io/docs/1.2/), but it's not super obvious how to do certain actions. Maybe the snippets below will come in handy for
someone someday.

The script below shows examples for perform `GET` and `POST` actions, specifically, 

* GET vm status
* POST vm start command
* POST vm shutdown command

```python
import proxmoxer
from pydantic import BaseModel
import os

# Define the configuration data for the ProxmoxVM object
config_data = {
    "hostname": f'{os.getenv("PVE_URL")}',
    "username": f'{os.getenv("PVE_USERNAME")}',
    "password": f'{os.getenv("PVE_PASSWORD")}',
    "node": f'{os.getenv("PVE_NODE")}',
    "vm_id": f'{os.getenv("VMID")}',
}

class ProxmoxVMConfig(BaseModel):
    hostname: str
    username: str
    password: str
    node: str
    vm_id: str

class ProxmoxVM:
    def __init__(self, config: ProxmoxVMConfig):
        self.proxmox = proxmoxer.ProxmoxAPI(
            config.hostname,
            user=config.username,
            password=config.password,
            verify_ssl=True, # set to False if you do not have a valid cert for your Proxmox server
        )
        self.vm = self.proxmox.nodes(config.node).qemu(config.vm_id)

    def start(self):
        self.vm.status.post("start")

    def shutdown(self):
        self.vm.status.post("shutdown")

    def status(self):
        status_dict = self.vm.status.current.get()
        return status_dict

# Create a ProxmoxVMConfig object from the configuration data
config = ProxmoxVMConfig(**config_data)
# Create a ProxmoxVM object from the configuration
vm = ProxmoxVM(config)
state = vm.status()

print(f"VM is {state}")

# shutdown the instance
vm.shutdown()
# start the instance
# vm.start()
```

## The Discord Bot

The discord bot ultimately built is [here](https://github.com/markopolo123/discord-proxmox-bot). It could be extended to control more aspects of a vm and provide a bit more feedback on what it's doing when a command has been submitted, but it's only me using it atm. 
