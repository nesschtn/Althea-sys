terraform {
  required_version = ">= 1.5.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# Provider Docker.
# Sur WSL avec Docker Desktop, le socket est expose via /var/run/docker.sock.
# Si tu utilises Docker installe directement dans WSL, c'est le meme chemin.
provider "docker" {
  host = "unix:///var/run/docker.sock"
}
