# Cavern Docker Environment

This project provides a complete, multi-container local development environment for the Cavern services, fully orchestrated with Docker Compose.

## 🚀 One-Time Setup

Services are managed using a `docker-compose.yml` file in the usual way, but you'll need to set your username. First tell the cavern service who the root owner of the VOSpace is. Edit: `platform/src-cavern/config/cavern.properties` and replace the username with your username that you use for SKA IAM (oidc-token) in the two places shown:

```
# platform/src-cavern/config/cavern.properties
org.opencadc.cavern.filesystem.rootOwner = NEW_USERNAME_HERE
org.opencadc.cavern.filesystem.rootOwner.username = NEW_USERNAME_HERE
# ... (other properties remain the same) ...
```

Now update the Database Initialization Script, adding the new user and their default group to the posix-mapper database when the services first start. Edit: platform/src-posix-mapper/db-init/data/01-add-test-user.sql and replace the existing username:

```
#platform/src-posix-mapper/db-init/data/01-add-test-user.sql
INSERT INTO posixmap.users (username) VALUES ('NEW_USERNAME_HERE') ON CONFLICT (username) DO NOTHING;
INSERT INTO posixmap.groups (groupuri) VALUES ('ivo://skao.int/groups/NEW_USERNAME_HERE') ON CONFLICT (groupuri) DO NOTHING;
```

Now bring up the entire application stack using Docker Compose:

```
docker compose up -d
```

To stop and remove all containers, networks, and volumes managed by Docker Compose:

```
docker compose down --volumes
```

***

## 🧩 Services Overview and Interactions

Your Docker Compose setup orchestrates a comprehensive development environment for Cavern services, including the `prepare-data` stack. These services are interconnected within the `src-network` network, using static IP addresses for reliable communication.

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

### Overall Data Flow

1.  External requests (e.g., `curl` commands from your terminal) come to `haproxy:443`.
2.  HAProxy authenticates the request and routes it to the appropriate backend service based on the URL path (e.g., requests to `/src/cavern` go to the `src-cavern` service).
3.  The `src-cavern` service receives the request (e.g., to create a new folder).
4.  To handle the request, `src-cavern` communicates with other backend services:
    * It queries `src-posix-mapper` to get the user's POSIX file permissions (UID/GID).
    * `src-posix-mapper` retrieves this information from its `postgres_posixmapper` database.
5.  `src-cavern` writes the new folder's metadata to its own `srcnodedb` database.
6.  `src-cavern` creates the actual folder on the local disk via its bind mount.
7.  A success (or error) response is sent back through HAProxy to the user's terminal.

***

## 🧪 Testing the Environment

Once all services are running, you can use these `curl` commands from your terminal to test the key endpoints. For `prepare-data` testing, ensure `PREPARE_DATA_APPROACH` is set to `cavern_api_approach` in your `docker-compose.yml`.

#### 1. Core Services Health Checks:

* **Registry Health Check (GET):** Verifies that HAProxy is routing to the `reg` service correctly.
    ```
    curl -k https://haproxy.cadc.dao.nrc.ca/reg/resource-caps
    ```
* **Cavern Service (GET & PUT):** Tests reading from and writing to the `src-cavern` service.
    * Get the root node:
        ```
        curl -k https://haproxy.cadc.dao.nrc.ca/src/cavern/nodes/
        ```
    * Create a new container node as your user (must replace username in command):
        ```
        curl -k -X PUT -H "Authorization: Bearer $SKA_TOKEN" -H "Content-Type: application/xml" -d '<?xml version="1.0" encoding="UTF-8"?><node xmlns="http://www.ivoa.net/xml/VOSpace/v2.0" uri="vos://skao.int~src~cavern/alexclarke_new_container" xsi:type="vs:ContainerNode" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:vs="http://www.ivoa.net/xml/VOSpace/v2.0"><vos:nodes xmlns:vos="http://www.ivoa.net/xml/VOSpace/v2.0"/></node>' https://localhost/src/cavern/nodes/alexclarke_new_container
        ```

* **POSIX Mapper Service (GET):** Tests the `src-posix-mapper` service by requesting user data.
    ```
    curl -k https://haproxy.cadc.dao.nrc.ca/src/posix-mapper/users/username
    ```
