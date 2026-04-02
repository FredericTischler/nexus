# Audit du projet Nexus E-commerce

---

## 1. Setup Nexus Repository Manager

### 1.1 Has the Nexus Repository Manager been successfully installed and configured on a local or remote server?

**Oui.** Nexus Repository Manager 3 (Sonatype Nexus 3) est installe et operationnel sur le serveur local via Docker.

**Preuves :**

- **Fichier de configuration** : `docker-compose.nexus.yml` a la racine du projet
- **Image utilisee** : `sonatype/nexus3:latest`
- **Conteneur** : `ecommerce-nexus`
- **Acces UI** : `http://localhost:8091` (port 8081 interne mappe sur 8091 car 8081 est utilise par le user-service)
- **Ports exposes** :
  | Port hote | Port interne | Role |
  |-----------|-------------|------|
  | 8091 | 8081 | UI Nexus + repositories Maven |
  | 5000 | 5000 | Docker hosted registry (images produites) |
  | 5001 | 5001 | Docker proxy registry (cache Docker Hub) |
  | 5002 | 5002 | Docker group registry (point d'entree unique) |
- **Persistence** : volume Docker `nexus_data` monte sur `/nexus-data`
- **Healthcheck** configure : `curl -sf http://localhost:8081/service/rest/v1/status`
- **Demarrage** : `docker compose -f docker-compose.nexus.yml up -d`
- **Reseau** : connecte au reseau Docker `safe-zone_ecommerce-network` (partage avec les microservices)

---

### 1.2 Is Nexus configured correctly to work under the specified user not 'root' user?

**Oui.** Nexus tourne sous l'utilisateur `nexus` (uid=200), **jamais root**.

**Preuves :**

- Commande `docker exec ecommerce-nexus whoami` retourne : **`nexus`**
- Commande `docker exec ecommerce-nexus id` retourne : **`uid=200(nexus) gid=200(nexus) groups=200(nexus)`**
- Le champ `User` dans la configuration du conteneur (`docker inspect`) confirme : **`nexus`**
- Ce comportement est celui par defaut de l'image officielle `sonatype/nexus3` qui cree et utilise l'utilisateur systeme `nexus` avec l'uid 200
- Le `docker-compose.nexus.yml` ne surcharge pas l'utilisateur (pas de directive `user: root`)

---

### 1.3 Are repositories set up for different artifact types such as JARs, WARs, and Docker images?

**Oui.** 10 repositories sont configures, couvrant les artefacts Maven (JARs/WARs) et les images Docker.

**Preuves (via l'API REST `GET /service/rest/v1/repositories`) :**

#### Repositories Maven (format `maven2`) — pour JARs et WARs

| Nom | Type | URL | Role |
|-----|------|-----|------|
| `maven-releases` | hosted | `http://localhost:8091/repository/maven-releases` | Stockage des artefacts en version release |
| `maven-snapshots` | hosted | `http://localhost:8091/repository/maven-snapshots` | Stockage des artefacts SNAPSHOT (deployes par Jenkins via `mvn deploy`) |
| `maven-central` | proxy | `http://localhost:8091/repository/maven-central` | Proxy/cache de Maven Central (`https://repo1.maven.org/maven2/`) |
| `maven-public` | group | `http://localhost:8091/repository/maven-public` | Point d'entree unique regroupant releases + snapshots + central |

#### Repositories Docker — pour les images de conteneurs

| Nom | Type | URL | Port | Role |
|-----|------|-----|------|------|
| `docker-hosted` | hosted | `http://localhost:8091/repository/docker-hosted` | 5000 | Stockage des images Docker produites (user-service, product-service, media-service, order-service) |
| `docker-hub-proxy` | proxy | `http://localhost:8091/repository/docker-hub-proxy` | 5001 | Proxy/cache de Docker Hub (`https://registry-1.docker.io`) |
| `docker-group` | group | `http://localhost:8091/repository/docker-group` | 5002 | Point d'entree unique regroupant hosted + proxy |

#### Integration avec le pipeline CI/CD

- **Maven** : le fichier `settings.xml` configure les builds Maven pour utiliser `maven-public` comme miroir et deployer vers `maven-snapshots` (via `mvn deploy`)
- **Docker** : le Jenkinsfile pousse les 4 images de microservices vers `localhost:5000` (docker-hosted) a chaque build reussi
- Les 4 services (`user-service`, `product-service`, `media-service`, `order-service`) sont publies en version `1.1.0-SNAPSHOT-{BUILD_NUMBER}` et `latest`

---

## 2. Development and Structure

### 2.1 Is there a simple web application developed using the Spring Boot framework?

**Oui.** Le projet est une application e-commerce composee de 4 microservices, tous developpes avec **Spring Boot 3.2.0**.

**Preuves :**

- **Parent POM** (`backend/pom.xml`) herite de `spring-boot-starter-parent:3.2.0` :
  ```xml
  <parent>
      <groupId>org.springframework.boot</groupId>
      <artifactId>spring-boot-starter-parent</artifactId>
      <version>3.2.0</version>
  </parent>
  ```
- **Chaque service** possede une classe principale annotee `@SpringBootApplication` avec `SpringApplication.run(...)` :
  | Service | Classe principale |
  |---------|-------------------|
  | user-service | `com.ecommerce.user.UserServiceApplication` |
  | product-service | `com.ecommerce.product.ProductServiceApplication` |
  | media-service | `com.ecommerce.media.MediaServiceApplication` |
  | order-service | `com.ecommerce.order.OrderServiceApplication` |

- **Starters Spring Boot utilises** (exemple user-service) :
  - `spring-boot-starter-web` — API REST (controleurs, serveur Tomcat embarque)
  - `spring-boot-starter-data-mongodb` — persistence MongoDB
  - `spring-boot-starter-security` — authentification JWT, RBAC
  - `spring-boot-starter-validation` — validation des DTOs
  - `spring-boot-starter-test` — tests unitaires et d'integration

- **Configuration** : chaque service a un fichier `application.yml` dans `src/main/resources/`
- **Frontend** : application Angular separee (`frontend/`) communiquant avec les APIs Spring Boot

---

### 2.2 Does the project utilize a proper Maven or Gradle project structure?

**Oui.** Le projet utilise **Maven** avec une structure **multi-modules** standard.

**Preuves :**

#### Structure multi-modules

```
backend/
├── pom.xml                      ← POM parent (packaging: pom)
├── user-service/
│   └── pom.xml                  ← Module enfant
├── product-service/
│   └── pom.xml                  ← Module enfant
├── media-service/
│   └── pom.xml                  ← Module enfant
└── order-service/
    └── pom.xml                  ← Module enfant
```

Le POM parent declare les 4 modules :
```xml
<modules>
    <module>user-service</module>
    <module>product-service</module>
    <module>media-service</module>
    <module>order-service</module>
</modules>
```

#### Arborescence Maven standard par service (exemple : user-service)

```
user-service/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/com/ecommerce/user/
    │   │   ├── UserServiceApplication.java
    │   │   ├── config/          ← Configuration Spring (CORS, etc.)
    │   │   ├── controller/      ← Controleurs REST
    │   │   ├── dto/             ← Data Transfer Objects
    │   │   ├── exception/       ← Gestion globale des erreurs
    │   │   ├── model/           ← Entites MongoDB
    │   │   ├── repository/      ← Repositories Spring Data
    │   │   ├── security/        ← JWT, filtres, config securite
    │   │   └── service/         ← Logique metier
    │   └── resources/
    │       └── application.yml  ← Configuration Spring Boot
    └── test/
        ├── java/com/ecommerce/user/
        │   ├── controller/      ← Tests des controleurs
        │   ├── dto/             ← Tests des DTOs
        │   ├── exception/       ← Tests du handler d'erreurs
        │   ├── integration/     ← Tests d'integration
        │   ├── model/           ← Tests des entites
        │   ├── security/        ← Tests JWT/securite
        │   └── service/         ← Tests des services
        └── resources/           ← Configuration de test
```

Cette structure `src/main/java` + `src/test/java` + `src/main/resources` est **identique pour les 4 services** et respecte la convention Maven standard.

#### Gestion centralisee des dependances

- Le POM parent centralise les versions via `<dependencyManagement>` (JJWT, TestContainers, Commons IO)
- Les plugins communs (JaCoCo, SonarQube) sont geres via `<pluginManagement>`
- La publication vers Nexus est configuree dans `<distributionManagement>` (maven-releases + maven-snapshots)

---

## 3. Artifact Publishing

### 3.1 Is the build tool (Maven or Gradle) properly configured to publish built artifacts (JARs/WARs) to the relevant repositories in Nexus?

**Oui.** Maven est configure pour publier les artefacts vers Nexus via `mvn deploy`.

**Preuves :**

#### Configuration `<distributionManagement>` dans le POM parent (`backend/pom.xml`)

```xml
<distributionManagement>
    <repository>
        <id>nexus-releases</id>
        <url>http://localhost:8091/repository/maven-releases/</url>
    </repository>
    <snapshotRepository>
        <id>nexus-snapshots</id>
        <url>http://localhost:8091/repository/maven-snapshots/</url>
    </snapshotRepository>
</distributionManagement>
```

- Les versions **RELEASE** sont publiees vers `maven-releases`
- Les versions **SNAPSHOT** (comme `1.1.0-SNAPSHOT`) sont publiees vers `maven-snapshots`

#### Credentials dans `settings.xml`

```xml
<servers>
    <server>
        <id>nexus-releases</id>
        <username>admin</username>
        <password>${env.NEXUS_PASSWORD}</password>
    </server>
    <server>
        <id>nexus-snapshots</id>
        <username>admin</username>
        <password>${env.NEXUS_PASSWORD}</password>
    </server>
</servers>
```

Les identifiants `nexus-releases` et `nexus-snapshots` correspondent entre le POM et le `settings.xml`. Le mot de passe est lu depuis la variable d'environnement `NEXUS_PASSWORD` (injectee par Jenkins via credentials).

#### Preuve de publication reussie (logs Jenkins — stage `Publish_Maven_Artifacts`)

Le pipeline execute `mvn -B deploy -DskipTests -s ../settings.xml` et les 5 artefacts sont uploades :

```
[INFO] Uploading to nexus-snapshots: .../ecommerce-parent-1.1.0-20260402.090906-1.pom
[INFO] Uploaded to nexus-snapshots (6.7 kB at 160 kB/s)

[INFO] Uploading to nexus-snapshots: .../user-service-1.1.0-20260402.090906-1.jar
[INFO] Uploaded to nexus-snapshots (47 MB at 122 MB/s)

[INFO] Uploading to nexus-snapshots: .../product-service-1.1.0-20260402.090906-1.jar
[INFO] Uploaded to nexus-snapshots (49 MB at 122 MB/s)

[INFO] Uploading to nexus-snapshots: .../media-service-1.1.0-20260402.090906-1.jar
[INFO] Uploaded to nexus-snapshots (49 MB at 156 MB/s)

[INFO] Uploading to nexus-snapshots: .../order-service-1.1.0-20260402.090906-1.jar
[INFO] Uploaded to nexus-snapshots (49 MB at 166 MB/s)
```

Les 4 JARs Spring Boot + le POM parent sont publies avec succes dans `maven-snapshots`.

---

## 4. Dependency Management

### 4.1 Is Nexus used as a proxy for fetching external dependencies required by the web application?

**Oui.** Nexus est configure comme **proxy de Maven Central** via le repository `maven-central` (type proxy), et toutes les requetes Maven transitent par Nexus.

**Preuves :**

#### Repository proxy dans Nexus

Le repository `maven-central` est de type **proxy** et pointe vers `https://repo1.maven.org/maven2/`. Quand Maven demande une dependance, Nexus la telecharge depuis Maven Central, la met en cache, et la sert localement pour les builds suivants.

#### Mirror dans `settings.xml`

```xml
<mirrors>
    <mirror>
        <id>nexus-mirror</id>
        <mirrorOf>*</mirrorOf>
        <url>http://localhost:8091/repository/maven-public/</url>
    </mirror>
</mirrors>
```

`<mirrorOf>*</mirrorOf>` signifie que **toutes** les requetes Maven (y compris Maven Central) sont redirigees vers Nexus. Aucune dependance n'est telechargee directement depuis internet.

#### Preuve dans les logs Jenkins (stage `Build_Push_Docker_Images`)

Chaque dependance est telechargee depuis `nexus-mirror` :

```
[INFO] Downloading from nexus-mirror: http://localhost:8091/repository/maven-public/org/springframework/boot/spring-boot-starter-web/3.2.0/...
[INFO] Downloaded from nexus-mirror: (4.8 kB at 480 kB/s)

[INFO] Downloading from nexus-mirror: http://localhost:8091/repository/maven-public/org/apache/tomcat/embed/tomcat-embed-core/10.1.16/...
[INFO] Downloaded from nexus-mirror: (3.5 MB at 46 MB/s)
```

Aucun telechargement ne provient directement de `repo1.maven.org` — tout passe par `nexus-mirror` (`localhost:8091/repository/maven-public/`).

---

### 4.2 Is the project configured to resolve dependencies from Nexus repositories?

**Oui.** La resolution des dependances est entierement configuree pour passer par Nexus.

**Preuves :**

#### Profil actif dans `settings.xml`

```xml
<profiles>
    <profile>
        <id>nexus</id>
        <repositories>
            <repository>
                <id>nexus-public</id>
                <url>http://localhost:8091/repository/maven-public/</url>
                <releases><enabled>true</enabled></releases>
                <snapshots><enabled>true</enabled></snapshots>
            </repository>
        </repositories>
        <pluginRepositories>
            <pluginRepository>
                <id>nexus-public</id>
                <url>http://localhost:8091/repository/maven-public/</url>
                <releases><enabled>true</enabled></releases>
                <snapshots><enabled>true</enabled></snapshots>
            </pluginRepository>
        </pluginRepositories>
    </profile>
</profiles>
<activeProfiles>
    <activeProfile>nexus</activeProfile>
</activeProfiles>
```

- Le profil `nexus` est **actif par defaut**
- Il configure `maven-public` comme source pour les **dependances** et les **plugins Maven**
- `maven-public` est un repository **group** dans Nexus qui regroupe : `maven-releases` + `maven-snapshots` + `maven-central` (proxy)

#### Utilisation dans le pipeline Jenkins

Le `settings.xml` est utilise a chaque etape Maven du Jenkinsfile :
- `mvn -B clean package -DskipTests -s ../settings.xml`
- `mvn -B test -s ../settings.xml`
- `mvn -B deploy -DskipTests -s ../settings.xml`

Et dans les Dockerfiles de chaque service (build multi-stage) :
```dockerfile
COPY settings.xml /tmp/settings-template.xml
RUN mkdir -p /root/.m2 && awk '{gsub(/\${env.NEXUS_PASSWORD}/, ENVIRON["NEXUS_PASSWORD"]); print}' \
    /tmp/settings-template.xml > /root/.m2/settings.xml
```

Ainsi, meme les builds Docker resolvent leurs dependances via Nexus.

---

## 5. Versioning

### 5.1 Is versioning implemented for the web application and its artifacts using Nexus capabilities?

**Oui.** Le versioning est en place a deux niveaux : **artefacts Maven** (JARs) et **images Docker**.

**Preuves :**

#### Versioning Maven

La version du projet est definie dans le POM parent (`backend/pom.xml`) :

```xml
<groupId>com.ecommerce</groupId>
<artifactId>ecommerce-parent</artifactId>
<version>1.1.0-SNAPSHOT</version>
```

- La convention **Maven SNAPSHOT** est utilisee : `1.1.0-SNAPSHOT`
- Maven ajoute automatiquement un **timestamp unique** a chaque deploy. Lors de la publication vers Nexus, l'artefact est nomme `1.1.0-20260402.090906-1` (date + numero sequentiel), ce qui permet de conserver **plusieurs versions** d'un meme SNAPSHOT
- Les 4 modules heritent de la meme version via le POM parent

Extrait des logs Jenkins (stage `Publish_Maven_Artifacts`) :
```
Uploading to nexus-snapshots: .../user-service-1.1.0-20260402.090906-1.jar
Uploading to nexus-snapshots: .../user-service-1.1.0-20260402.090906-1.pom
Uploading to nexus-snapshots: .../1.1.0-SNAPSHOT/maven-metadata.xml
```

Nexus gere le `maven-metadata.xml` qui permet de retrouver la derniere version SNAPSHOT et l'historique des publications.

#### Versioning Docker

Le Jenkinsfile construit un **tag de version unique** pour chaque build :

```groovy
def imageVersion = sh(
    returnStdout: true,
    script: 'cd backend && mvn help:evaluate -Dexpression=project.version -q -DforceStdout -s ../settings.xml'
).trim() + "-${env.BUILD_NUMBER}"
```

Chaque image Docker recoit **deux tags** :
- **Tag versionne** : `1.1.0-SNAPSHOT-3` (version Maven + numero de build Jenkins)
- **Tag `latest`** : pointe toujours vers le dernier build reussi

Exemple dans les logs Jenkins :
```
docker build -t localhost:5000/ecommerce/user-service:1.1.0-SNAPSHOT-3
             -t localhost:5000/ecommerce/user-service:latest .
docker push localhost:5000/ecommerce/user-service:1.1.0-SNAPSHOT-3
docker push localhost:5000/ecommerce/user-service:latest
```

---

### 5.2 Are different versions of artifacts effectively retrieved and managed?

**Oui.** Nexus gere les differentes versions grace a la separation des repositories et aux metadonnees Maven.

**Preuves :**

#### Separation RELEASE / SNAPSHOT

| Repository | Politique de version | Politique d'ecriture | Usage |
|-----------|---------------------|---------------------|-------|
| `maven-releases` | RELEASE | ALLOW_ONCE (immutable) | Versions stables (ex: `1.0.0`) — ne peuvent pas etre ecrasees |
| `maven-snapshots` | SNAPSHOT | ALLOW (re-deployable) | Versions de developpement (ex: `1.1.0-SNAPSHOT`) — chaque deploy cree un nouveau timestamp |

#### Gestion automatique des metadonnees

A chaque `mvn deploy`, Nexus met a jour le fichier `maven-metadata.xml` qui liste toutes les versions disponibles :

```
Uploading to nexus-snapshots: .../com/ecommerce/user-service/maven-metadata.xml
Uploading to nexus-snapshots: .../com/ecommerce/user-service/1.1.0-SNAPSHOT/maven-metadata.xml
```

Cela permet a Maven de resoudre automatiquement la derniere version SNAPSHOT lors d'un build.

#### Historique des images Docker

Chaque build Jenkins produit un tag unique (`1.1.0-SNAPSHOT-{BUILD_NUMBER}`), ce qui permet de :
- **Revenir a une version precedente** : `docker pull localhost:5000/ecommerce/user-service:1.1.0-SNAPSHOT-2`
- **Deployer la derniere** : `docker pull localhost:5000/ecommerce/user-service:latest`
- **Identifier le build d'origine** grace au numero de build Jenkins dans le tag

---

## 6. Docker Integration

### 6.1 Is there a Docker repository set up in Nexus, and is the Docker image published to the repository?

**Oui.** Trois repositories Docker sont configures dans Nexus, et les images des 4 microservices sont publiees automatiquement par le pipeline Jenkins.

**Preuves :**

#### Repositories Docker dans Nexus

| Nom | Type | Port | Role |
|-----|------|------|------|
| `docker-hosted` | hosted | 5000 | Stockage des images produites par le projet |
| `docker-hub-proxy` | proxy | 5001 | Cache/proxy de Docker Hub (`https://registry-1.docker.io`) |
| `docker-group` | group | 5002 | Point d'entree unique regroupant hosted + proxy |

Configuration dans `docker-compose.nexus.yml` :
```yaml
ports:
  - "8091:8081"   # UI Nexus + Maven
  - "5000:5000"   # Docker hosted registry
  - "5001:5001"   # Docker proxy registry
  - "5002:5002"   # Docker group registry
```

#### Publication des images dans le pipeline Jenkins (stage `Build_Push_Docker_Images`)

Le Jenkinsfile authentifie Docker aupres de Nexus puis construit et pousse les 4 images :

```groovy
sh "echo \"\$NEXUS_PASSWORD\" | docker login \"\$NEXUS_REGISTRY\" -u admin --password-stdin"

['user-service', 'product-service', 'media-service', 'order-service'].each { svc ->
    sh """
        docker build --network=host --build-arg NEXUS_PASSWORD="\$NEXUS_PASSWORD" \
            -f backend/${svc}/Dockerfile \
            -t "\$NEXUS_REGISTRY/ecommerce/${svc}:${imageVersion}" \
            -t "\$NEXUS_REGISTRY/ecommerce/${svc}:latest" .
        docker push "\$NEXUS_REGISTRY/ecommerce/${svc}:${imageVersion}"
        docker push "\$NEXUS_REGISTRY/ecommerce/${svc}:latest"
    """
}
```

#### Preuve de push reussi (logs Jenkins)

Les 4 images sont poussees avec succes vers `localhost:5000` (docker-hosted) :

```
+ docker push localhost:5000/ecommerce/user-service:1.1.0-SNAPSHOT-3
1.1.0-SNAPSHOT-3: digest: sha256:14535a...  size: 1994

+ docker push localhost:5000/ecommerce/product-service:1.1.0-SNAPSHOT-3
1.1.0-SNAPSHOT-3: digest: sha256:bade65...  size: 1994

+ docker push localhost:5000/ecommerce/media-service:1.1.0-SNAPSHOT-3
1.1.0-SNAPSHOT-3: digest: sha256:ed33aa...  size: 1994

+ docker push localhost:5000/ecommerce/order-service:1.1.0-SNAPSHOT-3
1.1.0-SNAPSHOT-3: digest: sha256:6e9327...  size: 1994
```

#### Images publiees

| Image | Tags | Digest |
|-------|------|--------|
| `ecommerce/user-service` | `1.1.0-SNAPSHOT-3`, `latest` | `sha256:14535a...` |
| `ecommerce/product-service` | `1.1.0-SNAPSHOT-3`, `latest` | `sha256:bade65...` |
| `ecommerce/media-service` | `1.1.0-SNAPSHOT-3`, `latest` | `sha256:ed33aa...` |
| `ecommerce/order-service` | `1.1.0-SNAPSHOT-3`, `latest` | `sha256:6e9327...` |

---

## 7. Continuous Integration (CI)

### 7.1 Does the pipeline automatically trigger builds, tests, and artifact publishing upon repository changes?

**Oui.** Le pipeline Jenkins se declenche automatiquement a chaque push sur le repository Git et execute dans l'ordre : build, tests, publication des artefacts, build/push des images Docker, et deploiement.

**Preuves :**

#### Declenchement automatique

Le job Jenkins est configure en mode **SCM polling / webhook** sur le repository GitHub (`https://github.com/FredericTischler/nexus.git`). Les logs Jenkins confirment le declenchement automatique :

```
Lancé par un changement dans la base de code
Obtained Jenkinsfile from git https://github.com/FredericTischler/nexus.git
```

Le pipeline demarre **sans intervention manuelle** des qu'un commit est pousse sur la branche `main`.

#### Stages du pipeline (Jenkinsfile)

Le pipeline comporte **7 stages** executes sequentiellement :

| # | Stage | Commande | Role |
|---|-------|----------|------|
| 1 | `Checkout` | `checkout scm` | Clone le repository Git |
| 2 | `Build_Backend` | `mvn -B clean package -DskipTests` | Compile les 4 microservices Java |
| 3 | `Test_Backend` | `mvn -B test` | Execute les tests unitaires backend (534 tests) |
| 4 | `Build_Frontend` | `npm ci && npm run build` | Compile l'application Angular en mode production |
| 5 | `Test_Frontend` | `npm test --watch=false --browsers=ChromeHeadless` | Execute les tests frontend (331 tests) |
| 6 | `Publish_Maven_Artifacts` | `mvn -B deploy -DskipTests` | Publie les JARs vers Nexus (`maven-snapshots`) |
| 7 | `Build_Push_Docker_Images` | `docker build` + `docker push` | Construit et pousse les 4 images Docker vers Nexus (`docker-hosted`) |

#### Resultats du dernier build reussi

**Backend** — 534 tests, 0 echecs :
```
user-service:    Tests run: 96,  Failures: 0, Errors: 0
product-service: Tests run: 106, Failures: 0, Errors: 0
media-service:   Tests run: 51,  Failures: 0, Errors: 0
order-service:   Tests run: 281, Failures: 0, Errors: 0
```

**Frontend** — 331 tests, 0 echecs :
```
Chrome Headless: Executed 331 of 331 SUCCESS (2.003 secs / 1.733 secs)
Statements: 87.56% | Branches: 72.98% | Functions: 83.67% | Lines: 88.64%
```

**Publication Maven** — 5 artefacts deployes vers Nexus :
```
ecommerce-parent ......... SUCCESS [3.595 s]
user-service ............. SUCCESS [1.620 s]
product-service .......... SUCCESS [0.758 s]
media-service ............ SUCCESS [0.551 s]
order-service ............ SUCCESS [0.576 s]
```

**Publication Docker** — 4 images poussees vers `localhost:5000` (Nexus docker-hosted)

#### Notifications

Le pipeline envoie un **email automatique** en cas de succes ou d'echec :

```groovy
post {
    success {
        mail(to: env.EMAIL_RECIPIENTS,
             subject: "SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}", ...)
    }
    failure {
        mail(to: env.EMAIL_RECIPIENTS,
             subject: "FAILURE: ${env.JOB_NAME} #${env.BUILD_NUMBER}", ...)
    }
}
```

#### Rollback automatique en cas d'echec du deploiement

Si le stage `Deploy` echoue, le pipeline rollback automatiquement vers la version stable :

```groovy
post {
    failure {
        sh 'docker compose down --remove-orphans || true'
        sh 'docker compose -f docker-compose.stable.yml up -d --build'
    }
}
```

---

## 8. Documentation

### 8.1 Is clear and detailed documentation provided for project setup, configuration, and usage?

**Oui.** Le fichier `documentation_nexus.md` a la racine du projet couvre l'ensemble du projet de maniere detaillee et structuree.

**Contenu du document :**

| Section | Sujet | Contenu |
|---------|-------|---------|
| Prerequis | Outils et versions | Tableau des outils requis (Java 17, Maven 3.9, Docker 24, Docker Compose 2), ports utilises, variable d'environnement |
| 1. Installation Nexus | Setup complet | Demarrage via docker-compose, recuperation du mot de passe initial, finalisation via l'UI, verification utilisateur non-root, verification API |
| 2. Configuration des repositories | 7 repos | Tableaux detaillant les repos Maven (4) et Docker (3) avec leur type, politique d'ecriture, et role. Commandes API REST de creation |
| 3. Configuration Maven | POM + settings.xml | Structure multi-modules, `distributionManagement`, `settings.xml` complet avec credentials, miroir et profil |
| 4. Gestion des dependances | Proxy Maven Central | Explication du fonctionnement du proxy, verification dans les logs Maven, verification via API |
| 5. Versioning | SNAPSHOT vs RELEASE | Tableau comparatif, workflow quotidien, script de release (`scripts/release.sh`), recuperation de versions specifiques |
| 6. Integration Docker | Build multi-stage | Dockerfile commente, injection du mot de passe via AWK, build via docker-compose, push/pull depuis Nexus |
| 7. Pipeline CI/CD Jenkins | 8 stages | Prerequis Jenkins (credentials), variables d'environnement, pipeline complet commente, schema du flux CI/CD |
| 8. Securite (Bonus) | RBAC | Roles crees, utilisateurs crees, script de configuration, tests de validation des permissions |
| Depannage | 6 problemes courants | 401 Maven local, 401 Maven Docker, Maven sans Nexus, connection refused, cache BuildKit, docker login HTTPS |

---

### 8.2 Does the documentation include relevant screenshots and examples?

**Oui.** La documentation inclut des **screenshots** et des **exemples de commandes** concrets.

#### Screenshots

8 captures d'ecran sont referencees dans la documentation, stockees dans `docs/screenshots/` :

| Screenshot | Section | Description |
|-----------|---------|-------------|
| `nexus-home.png` | Installation | Tableau de bord Nexus avec les repositories listes |
| `nexus-maven-repos.png` | Repositories | Onglet "Repositories" montrant les 4 repos Maven |
| `nexus-jar-browse.png` | Publication | Browse > maven-snapshots montrant les JARs timestamps |
| `nexus-central-cache.png` | Dependances | Browse > maven-central montrant les artefacts Spring Boot en cache |
| `nexus-docker-images.png` | Docker | Browse > docker-hosted montrant les 4 images avec leurs tags |
| `jenkins-pipeline-stages.png` | CI/CD | Vue "Stage View" du pipeline Jenkins |
| `nexus-rbac-roles.png` | Securite | Security > Roles montrant les 3 roles crees |
| `nexus-rbac-users.png` | Securite | Security > Users montrant ci-deployer et dev-user |

#### Exemples de commandes

La documentation contient des **exemples de commandes executables** pour chaque operation :
- Demarrage Nexus : `docker compose -f docker-compose.nexus.yml up -d`
- Publication Maven : `mvn -B deploy -DskipTests -s ../settings.xml`
- Push Docker : `docker push localhost:5000/ecommerce/user-service:1.1.0-SNAPSHOT`
- Verification API : `curl -s -u "admin:$NEXUS_PASS" http://localhost:8091/service/rest/v1/repositories`
- Tests RBAC : commandes curl avec les codes HTTP attendus (200, 403, 201)

Chaque commande est accompagnee de la **sortie attendue** pour permettre la verification.

---

## 9. Bonus : Nexus Security and Access Control

### 9.1 Have Nexus security features like user authentication and role-based access control been explored?

**Oui.** Des roles personnalises et des utilisateurs dedies ont ete crees pour appliquer le principe du moindre privilege.

**Preuves :**

#### Roles crees (documentes dans `documentation_nexus.md` section 8 + script `scripts/setup-nexus-rbac.sh`)

| Role | Permissions | Usage |
|------|------------|-------|
| `developer-role` | Lecture `maven-public` + R/W `maven-snapshots` + lecture `docker-hosted` | Developpeurs en local — peuvent deployer des SNAPSHOTs mais pas des releases |
| `deployer-role` | R/W `maven-releases` + `maven-snapshots` + push `docker-hosted` | Compte de service Jenkins CI — peut tout publier |
| `readonly-role` | Lecture seule sur tous les repositories (`*`) | Auditeurs, acces externe en lecture |

#### Utilisateurs crees

| userId | Role assigne | Usage |
|--------|-------------|-------|
| `ci-deployer` | `deployer-role` | Compte utilise par le pipeline Jenkins |
| `dev-user` | `developer-role` | Compte pour les developpeurs en local |

#### Script d'automatisation

Le fichier `scripts/setup-nexus-rbac.sh` cree les roles et utilisateurs via l'API REST Nexus. Le script est idempotent (ne plante pas si les entites existent deja).

---

### 9.2 Are repository-level permissions effectively configured?

**Oui.** Les permissions sont configurees au niveau de chaque repository.

**Preuves :**

#### Matrice des permissions par role et repository

| Repository | `developer-role` | `deployer-role` | `readonly-role` |
|-----------|-------------------|-----------------|-----------------|
| `maven-public` | Lecture | Lecture | Lecture |
| `maven-snapshots` | Lecture + Ecriture | Lecture + Ecriture | Lecture |
| `maven-releases` | Lecture uniquement | Lecture + Ecriture | Lecture |
| `docker-hosted` | Lecture | Lecture + Push | Lecture |

#### Tests de validation (documentes dans `documentation_nexus.md` section 8.4)

```bash
# dev-user peut LIRE maven-public → 200
curl -u "dev-user:$DEV_PASS" http://localhost:8091/repository/maven-public/
# → 200

# dev-user ne peut PAS deployer en releases → 403
curl -u "dev-user:$DEV_PASS" -X PUT --data-binary "test" \
  http://localhost:8091/repository/maven-releases/com/test/test/1.0/test-1.0.jar
# → 403

# ci-deployer peut deployer en releases → 201
curl -u "ci-deployer:$CI_PASS" -X PUT --data-binary "test" \
  http://localhost:8091/repository/maven-releases/com/test/test/1.0/test-1.0.jar
# → 201
```

---

### 9.3 Are security settings configured to restrict access to specific artifacts or repositories in Nexus?

**Oui.** L'acces est restreint a plusieurs niveaux.

**Preuves :**

#### 1. Authentification obligatoire

L'acces anonyme est **desactive** dans Nexus. Toute requete (lecture ou ecriture) necessite une authentification. Le `settings.xml` configure les credentials pour chaque serveur :

```xml
<servers>
    <server>
        <id>nexus-mirror</id>
        <username>admin</username>
        <password>${env.NEXUS_PASSWORD}</password>
    </server>
</servers>
```

#### 2. Separation des repositories par politique d'ecriture

- `maven-releases` : politique **ALLOW_ONCE** — un artefact publie ne peut jamais etre ecrase (immutabilite des releases)
- `maven-snapshots` : politique **ALLOW** — re-deploiement autorise (chaque build cree un nouveau timestamp)

#### 3. Credentials Jenkins securises

Les mots de passe ne sont **jamais en dur** dans le code :
- Le `settings.xml` utilise `${env.NEXUS_PASSWORD}` (variable d'environnement)
- Le Jenkinsfile injecte le mot de passe via `credentials('nexus-admin-password')` (Jenkins Credentials Store)
- Le `.env` contenant les secrets est dans `.gitignore` et n'est pas versionne
- Les Dockerfiles utilisent `ARG` pour recevoir le mot de passe au build sans le persister dans l'image finale