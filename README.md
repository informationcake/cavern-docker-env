# Cavern Docker Environment

This project provides a complete, multi-container local development environment for the Cavern services, now including the `prepare-data` service, fully orchestrated with Docker.

## Prerequisites
* Docker and Docker Desktop installed and running.
* The `ska-src-dm-local-data-preparer` repository cloned to your `${HOME}` directory (as specified in `docker-compose.yml` build contexts).
* Required local data directories for services:
    * `./data/cavern_data`
    * `./data/rse_data`
    * `./logs/celery_results`

***

## 🚀 One-Time Setup

A setup script automates the entire one-time configuration process. This script creates the custom Docker network, sets up host entries, and generates necessary SSL certificates.

From the root of the project, run:

```
./scripts/setup_patrick_containers.sh
```

This script will:
1.  Create a custom Docker network named `docker26` with the `172.26.0.0/16` subnet.
2.  Copy the `docker-static-ip` utility script to `~/bin/`.
3.  Generate a self-signed SSL certificate for HAProxy and extract its public part for Java Trust Store compatibility.
4.  Add `haproxy.cadc.dao.nrc.ca` to your `/etc/hosts` file.

***

## 🛠️ Managing Services

Services are managed using a `docker-compose.yml` file, which is configured to use the `docker26` network created by the one-time setup script.

### To Start All Services:

After completing the One-Time Setup, bring up the entire application stack using Docker Compose:

```
docker compose up -d
```

### To Stop All Services:

To stop and remove all containers, networks, and volumes managed by Docker Compose:

```
docker compose down --volumes
```

***

## 🧩 Services Overview and Interactions

Your Docker Compose setup orchestrates a comprehensive development environment for Cavern services, now including your `prepare-data` stack. These services are interconnected within the `docker26` network, using static IP addresses for reliable communication.

### Core Services and Their Interactions

1.  **`haproxy`** (Container Name: `haproxy`):
    * **Purpose:** Acts as the central entry point for all external HTTPS traffic (on host port 443) into the environment. It performs SSL/TLS termination and routes requests to the appropriate backend services based on the URL path.
    * **Interactions:** All external communication to `reg`, `src-posix-mapper`, and `src-cavern` goes through HAProxy. Internal services (like `core` and `celery-worker`) also use HAProxy to communicate with `src-cavern`.

2.  **`reg`** (Container Name: `reg`):
    * **Purpose:** A mock IVOA Registry service. It serves as a central repository for service capabilities and resource identifiers, allowing other services to discover each other.
    * **Interactions:** Services like `src-cavern` and `src-posix-mapper` are configured to query `reg` to resolve resource IDs to service URLs.

3.  **`src-posix-mapper`** (Container Name: `src-posix-mapper`):
    * **Purpose:** Handles POSIX user and group ID mapping. It translates user identities into numerical UIDs and GIDs, which is crucial for VOSpace operations related to file ownership and permissions.
    * **Interactions:** Stores its mapping data in `postgres_posixmapper`. `src-cavern` queries `src-posix-mapper` to resolve user identities to POSIX IDs when performing VOSpace operations.

4.  **`srcnodedb`** (Container Name: `srcnodedb`):
    * **Purpose:** A dedicated PostgreSQL database instance for `src-cavern`, primarily storing data for Cavern's Universal Worker Service (UWS).
    * **Interactions:** Provides the backend database for `src-cavern`.

5.  **`postgres_posixmapper`** (Container Name: `postgres_posixmapper`):
    * **Purpose:** A dedicated PostgreSQL database instance for `src-posix-mapper`, storing its mapping data.
    * **Interactions:** Serves as the database backend for `src-posix-mapper`.

6.  **`src-cavern`** (Container Name: `src-cavern`):
    * **Purpose:** The core VOSpace service. It provides VOSpace functionality, including node management and data transfers.
    * **Interactions:** Relies on `srcnodedb` for its UWS database. It interacts with `src-posix-mapper` for user identity resolution. It receives API calls via HAProxy. When the `prepare-data` service uses the `cavern_api_approach`, `src-cavern` performs the actual data pulling from `rse-web`.

### Prepare-Data Services and Their Interactions

7.  **`rabbitmq`** (Container Name: `ska-src-local-data-preparer-rabbitmq`):
    * **Purpose:** A message broker for Celery tasks. It facilitates asynchronous communication between the `core` API service and the `celery-worker`.
    * **Interactions:** `core` dispatches tasks to `rabbitmq`, and `celery-worker` consumes tasks from `rabbitmq`.

8.  **`core`** (Container Name: `ska-src-local-data-preparer-core`):
    * **Purpose:** The main `prepare-data` FastAPI REST API. It receives data staging requests, authenticates users, and dispatches these requests as asynchronous tasks to the `celery-worker` via `rabbitmq`.
    * **Interactions:** Communicates with `celery-worker` via `rabbitmq`. When processing requests, it prepares task arguments that include API details (`CAVERN_API_URL`, `CAVERN_API_TOKEN`) and the source URL for RSE data (`ABS_URL_RSE_ROOT`), which are passed to the `celery-worker`.

9.  **`celery-worker`** (Container Name: `ska-src-local-data-preparer-celery-worker`):
    * **Purpose:** Executes the actual data preparation tasks (e.g., staging data to Cavern) in the background, as instructed by the `core` service.
    * **Interactions:** Connects to `rabbitmq` to fetch tasks. When running the `cavern_api_approach`, it uses the `CavernApiClient` to make API calls to `src-cavern` (via HAProxy). Crucially, when `CavernApiClient` tells `src-cavern` to pull data via `httpget`, `src-cavern` will fetch data from `rse-web`.

10. **`rse-web`** (Container Name: `rse-web`):
    * **Purpose:** A simple Nginx web server specifically for local development that serves the RSE (source) data via HTTP.
    * **Interactions:** It exposes the local `data/rse_data` bind mount over HTTP. `src-cavern` (when instructed by the `celery-worker` via the `cavern_api_approach`) makes HTTP GET requests to `rse-web` to pull the actual data files.

### Overall Data Flow

1.  External requests (e.g., `curl` commands from your terminal) come to `haproxy:443`.
2.  HAProxy routes data preparation requests to `ska-src-local-data-preparer-core:8000`.
3.  `core` receives the request, authenticates, and dispatches a data preparation task to `rabbitmq`.
4.  `celery-worker` picks up the task from `rabbitmq`.
5.  `celery-worker` (using the `cavern_api_approach`) initiates an API call to `src-cavern` (via HAProxy) to request a data transfer.
6.  `src-cavern`, upon receiving the `pullToVoSpace` instruction, makes an `httpget` request to `rse-web` to fetch the data.
7.  `rse-web` serves the file content from the locally mounted RSE data.
8.  `src-cavern` pulls the data and stages it into its VOSpace (which uses its `srcnodedb` database and local filesystem mounts).
9.  `celery-worker` monitors the task completion and reports status back to `core` via `rabbitmq`.
10. `core` can then provide the task status to the original requester.

***

## 🧪 Testing the Environment

Once all services are running, you can use these `curl` commands from your terminal to test the key endpoints. For `prepare-data` testing, ensure `PREPARE_DATA_APPROACH` is set to `cavern_api_approach` in your `docker-compose.yml`.

#### 1. Core Services Health Checks:

* **Registry Health Check (GET):** Verifies that HAProxy is routing to the `reg` service correctly.
    ```
    curl -k [https://haproxy.cadc.dao.nrc.ca/reg/resource-caps](https://haproxy.cadc.dao.nrc.ca/reg/resource-caps)
    ```
* **Cavern Service (GET & PUT):** Tests reading from and writing to the `src-cavern` service.
    * Get the root node:
        ```
        curl -k [https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/](https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/)
        ```
    * Create a new container node:
        ```
        curl -k -X PUT -H "Content-Type: application/xml" PLACEHOLDER_BACKTICK\
        -d '<?xml version="1.0" encoding="UTF-8"?><node xmlns="[http://www.ivoa.net/xml/VOSpace/v2.0](http://www.ivoa.net/xml/VOSpace/v2.0)" xsi:type="vs:ContainerNode" xmlns:xsi="[http://www.w3.org/2001/XMLSchema-instance](http://www.w3.org/2001/XMLSchema-instance)" xmlns:vs="[http://www.ivoa.net/xml/VOSpace/v2.0](http://www.ivoa.net/xml/VOSpace/v2.0)"/>' PLACEHOLDER_BACKTICK\
        [https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/test_container](https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/test_container)
        ```
* **POSIX Mapper Service (GET):** Tests the `src-posix-mapper` service by requesting user data.
    ```
    curl -k [https://haproxy.cadc.dao.nrc.ca/src/posix-mapper/users/pdowler](https://haproxy.cadc.dao.nrc.ca/src/posix-mapper/users/pdowler)
    ```
    *Note:* A `404 Not Found` response is expected and indicates success if the user does not exist in the database.

#### 2. Prepare-Data Service (Core & Celery Worker):

WORK IN PROGRESS

To test the `prepare-data` service, you'll typically submit tasks to the `core` service. Since `core` is not exposed on your host, you'll execute `curl` commands from inside another container on the same Docker network (e.g., `haproxy`).

* **Prerequisites for `cavern_api_approach`:**
    * Ensure `PREPARE_DATA_APPROACH: cavern_api_approach` is set in your `docker-compose.yml` for `core` and `celery-worker`.
    * Ensure `ABS_URL_RSE_ROOT` is correctly configured in `docker-compose.yml` to point to your `rse-web` service (e.g., `http://rse-web:80/rse/deterministic`).
    * Place a test file (e.g., `prepare_data_test.txt`) at the correct path within your `./data/rse_data/testing/84/1c/` directory, so `rse-web` can serve it.
    * You will need a valid `SKA_IAM_TOKEN`.

* **Submit a Data Preparation Task:**
    This will trigger the `prepare_data_task` using the `cavern_api_approach`.
    ```
    docker exec haproxy curl -X 'POST' \
      -H 'accept: application/json' \
      -H 'Content-Type: application/json' \
      -H 'Authorization: Bearer SKA_IAM_TOKEN' \
      -d '[
        [
          "testing:prepare_data_test.txt",
          "testing/84/1c/prepare_data_test.txt",
          "./testing"
        ]
      ]' \
      http://ska-src-local-data-preparer-core:8000/
    ```
    *Expected result:* A JSON response containing a `task_id` (e.g., `{"task_id":"..."}`).

* **Check the Status of the Submitted Task:**
    Replace `YOUR_TASK_ID` with the ID obtained from the previous step.
    ```
    docker exec haproxy curl -X 'GET' \
      -H 'accept: application/json' \
      -H 'Authorization: Bearer SKA_IAM_TOKEN' \
      http://ska-src-local-data-preparer-core:8000/YOUR_TASK_ID
    ```
    *Expected result:* `{"status":"SUCCESS","info":"Data provisioning successful"}` (or `PENDING`/`STARTED` if not yet complete).

* **Monitor Logs for Execution Details:**
    Check the logs of `celery-worker` and `src-cavern` for messages from your `CavernApiApproach` (e.g., "Ensuring user directory...", "Staging file from...", "Successfully staged file...") and Cavern's response.
    ```
    docker logs ska-src-local-data-preparer-celery-worker
    docker logs src-cavern
    ```
