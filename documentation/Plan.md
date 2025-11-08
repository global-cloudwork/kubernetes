Task Set 1: Infrastructure & Deployment

This set focuses on ensuring all the required applications and services are correctly deployed and networked within your RKE2 Kubernetes environment, using the specified Gateway API and Cilium network policies. 

|Task Category|
|---|

||Task Description|Key Tools/Components|
|---|---|---|
|**Kubernetes Setup**|Verify the RKE2 cluster is operational and the Gateway API and Cilium are installed/configured.|RKE2, kubectl, Cilium CLI|
|**Application Deployment**|Deploy all core applications (n8n, Firecrawl, Neo4j, OpenWebUI) using Kubernetes manifests (e.g., Helm charts or custom YAMLs).|Kubernetes, Helm, Docker|
|**Networking & Security**|Configure `Gateway API` resources (Gateways, HTTPRoutes) to expose n8n, Firecrawl API, Neo4j, and OpenWebUI externally.|Gateway API, Cilium Network Policies|
|**Database Preparation**|Deploy the Neo4j instance within Kubernetes and run initial setup scripts to create the premade schema for different entity types.|Neo4j, Cypher queries, Kubernetes PVCs|
|**Service Connectivity**|Implement Cilium Network Policies to ensure only authorized components can communicate (e.g., n8n can reach the Firecrawl and Neo4j services, but not vice-versa).|Cilium, Kubernetes Services|

Task Set 2: Data Ingestion Pipeline Development (n8n Workflow)

This set focuses on building the core n8n workflow that orchestrates the scraping, extraction, and knowledge graph population process. 

|Task Category|
|---|

||Task Description|Key Tools/Components|
|---|---|---|
|**Workflow Trigger**|Set up a trigger in n8n that initiates the workflow based on user input from OpenWebUI or a Google Sheet entry.|n8n (Webhooks/Google Sheets node)|
|**Data Retrieval**|Use the n8n HTTP Request or Firecrawl node to send the target webpage URL to the Firecrawl service for scraping.|n8n (Firecrawl/HTTP Node), Firecrawl API|
|**Schema & Entity Extraction**|Configure Firecrawl's extract feature with a specific prompt/JSON schema based on the chosen entity type to get structured data (using `schema.org` entities).|Firecrawl API, LLM Prompts, JSON Schema|
|**Data Transformation**|Process the extracted data within n8n to map it correctly to the Neo4j schema and generate the required Cypher queries.|n8n (Code/Data transformation nodes), Javascript/Python|
|**Knowledge Graph Ingestion**|Use n8n's Neo4j node or HTTP Request node to execute the generated Cypher queries and `MERGE` the structured data into the Neo4j knowledge graph.|n8n (Neo4j/HTTP Node), Neo4j, Cypher|

Task Set 3: User Interface & Interaction

This set focuses on the user-facing part, enabling users to interact with the system via OpenWebUI and Google Sheets to trigger the data ingestion. 

|Task Category|
|---|

||Task Description|Key Tools/Components|
|---|---|---|
|**OpenWebUI Integration**|Configure OpenWebUI to allow users to input a webpage URL and select an entity type from a predefined list (possibly fetched from a Google Sheet).|OpenWebUI, User Interface|
|**User Input Handling**|Link OpenWebUI's output to an n8n webhook, passing the URL and entity type as parameters.|OpenWebUI, n8n Webhooks, API calls|
|**Type Management**|Maintain and manage the list of available `schema.org` types in a Google Sheet which n8n can read from.|Google Sheets, n8n (Google Sheets node)|
|**Feedback & Notification**|Add a step in the n8n workflow to send a status notification (success/failure) back to the user via OpenWebUI or another channel once the ingestion is complete.|n8n, OpenWebUI, Notification service|
|**Knowledge Graph Visualization**|Set up and expose the Neo4j Bloom/Browser interface for users to visualize and query the created knowledge graph.|Neo4j Browser/Bloom, Kubernetes Port-forwarding/Gateway|


Task ID

||Task Description|Category|Key Tools/Components|
|---|---|---|---|
|**D1**|Confirm RKE2 cluster, Gateway API, and Cilium are operational.|Deployment & Infra|RKE2, kubectl, Cilium|
|**D2**|Deploy n8n, Firecrawl API service, and the Neo4j database service using Kubernetes manifests (e.g., Helm).|Deployment & Infra|Kubernetes, Helm, Docker|
|**D3**|Use Gateway API HTTPRoutes to expose the n8n and Firecrawl API services to the internal cluster or external access points.|Deployment & Infra|Gateway API, Kubernetes Services|
|**D4**|Implement explicit Cilium Network Policies allowing _only_ the n8n pod to initiate connections to the Firecrawl and Neo4j service endpoints.|Deployment & Infra|Cilium Network Policies|
|**D5**|Manually run initial Cypher queries via Neo4j Browser/CLI to create a single, predefined generic schema for basic entities (e.g., `Page` nodes, `MENTIONS` relationships).|Deployment & Infra|Neo4j, Cypher queries|
|**W1**|Create an n8n `Webhook` trigger node to receive a URL and an LLM schema prompt as input JSON.|Workflow Development|n8n (Webhook Node)|
|**W2**|Use an n8n `HTTP Request` node to send the received URL to the _internal_ Firecrawl service endpoint to fetch the clean content.|Workflow Development|n8n (HTTP Node), Firecrawl API|
|**W3**|Use an n8n `HTTP Request` node to call the external API provider's LLM endpoint, passing the scraped content and the specific schema prompt to get structured JSON back.|Workflow Development|n8n (HTTP Node), External LLM API|
|**W4**|Use an n8n `Code` or `Item Lists` node to parse the returned JSON and transform it into the format required for the Neo4j Cypher query.|Workflow Development|n8n (Code Node), Javascript|
|**W5**|Use the n8n `Neo4j` community node or an `HTTP Request` node to execute a single, predefined Cypher query (`MERGE` statement) that inserts the structured data into the database.|Workflow Development|n8n (Neo4j/HTTP Node), Cypher, Neo4j|
|**T1**|Use Postman or `curl` to send a test payload (URL and schema prompt) to the n8n webhook and monitor the execution log for success.|Testing & Iteration|Postman/curl, n8n UI|
|**T2**|Query the Neo4j database directly using the Neo4j Browser to visually confirm that the new nodes and relationships were created correctly after the test run.|Testing & Iteration|Neo4j Browser, Cypher|