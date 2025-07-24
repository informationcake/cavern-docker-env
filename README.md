# Cavern Docker Environment

This project provides a complete, multi-container local development environment for the Cavern services, fully orchestrated with Docker.

## Prerequisites
* Docker and Docker Desktop installed and running.

***

## 🚀 One-Time Setup

A setup script automates the entire one-time configuration process. From the root of the project, run:

```bash
./scripts/setup_patrick_containers.sh
```
This script will:
1.  Create a custom Docker network named `docker26`.
2.  Copy the `docker-static-ip` utility script to `~/bin/`.
3.  Generate a self-signed SSL certificate for HAProxy.
4.  Add `haproxy.cadc.dao.nrc.ca` to your `/etc/hosts` file.

***

## 🛠️ Managing Services

A management script is provided to easily start and stop the entire application stack.

### To Start All Services:
```bash
./scripts/manage_patrick_containers.sh start
```
This will launch HAProxy, the application services, and their required PostgreSQL databases in the correct order.

### To Stop All Services:
```bash
./scripts/manage_patrick_containers.sh stop
```

### Manual Startup (for debugging)
If you need to start a single service to view its logs, navigate to its directory and run its `doit` script with the `-f` flag.
```bash
# Example for starting the reg service
cd infra/reg/
./doit -f
```
***

### Docker Compose version
May need to stop the 'docker26' network started by the management script first:
```bash
docker network rm docker26
```

```bash
# Start it up:
docker-compose up -d

# Check that four containers are running:
docker container ls

# Check the logs:
docker logs haproxy # Container is not running a syslog daemon so default logs to /dev/log are not showing
docker logs reg
docker logs src-posix-mapper
docker logs src-cavern

# Stop the containers:
docker compose down
```

***

## 🧪 Testing the Environment
Once all services are running, you can use these `curl` commands from your terminal to test the key endpoints.

#### 1. Registry Health Check (GET)
Verifies that HAProxy is routing to the `reg` service correctly.
```bash
curl -k [https://haproxy.cadc.dao.nrc.ca/reg/resource-caps](https://haproxy.cadc.dao.nrc.ca/reg/resource-caps)
```
#### 2. Cavern Service (GET & PUT)
Tests reading from and writing to the `src-cavern` service.

* **Get the root node:**
    ```bash
    curl -k [https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/](https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/)
    ```

* **Create a new container node:**
    ```bash
    curl -k -X PUT -H "Content-Type: application/xml" \
    -d '<?xml version="1.0" encoding="UTF-8"?><node xmlns="[http://www.ivoa.net/xml/VOSpace/v2.0](http://www.ivoa.net/xml/VOSpace/v2.0)" xsi:type="vs:ContainerNode" xmlns:xsi="[http://www.w3.org/2001/XMLSchema-instance](http://www.w3.org/2001/XMLSchema-instance)" xmlns:vs="[http://www.ivoa.net/xml/VOSpace/v2.0](http://www.ivoa.net/xml/VOSpace/v2.0)"/>' \
    [https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/test_container](https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/test_container)
    ```

#### 3. POSIX Mapper Service (GET)
Tests the `src-posix-mapper` service by requesting user data.
```bash
curl -k [https://haproxy.cadc.dao.nrc.ca/src/posix-mapper/users/pdowler](https://haproxy.cadc.dao.nrc.ca/src/posix-mapper/users/pdowler)
```
**Note:** A `404 Not Found` response is expected and indicates success, as the user does not exist in the new database.
