# To add an application
1. browse artifacthub.io for the details seen below
2. ask if it's exposed: port, path, service
3. the chart name from artifacthub is the alias 
4. create a folder in /applications with the alias
5. fill details in new files kustomize and namespace
6. chose http or https and fill httproutes if needed

```yaml
#kustomization.yaml - deployed using file discovery
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - httproute.yaml #only if required

helmCharts:
  - name: alias
    repo: browse result
    namespace: alias
    version: browse result
    releaseName: alias
    valuesInline:

--- 
#aditional helm charts, or other

```

namespace.yaml (referenced by kustomize.yaml)
```yaml
#namespace.yaml - reference in kustomizeation.yaml
apiVersion: v1
kind: Namespace
metadata:
    name: alias
---
#additional namespaces

```

```yaml
#httproute.yaml - optional, in kustomizeation.yaml

#appended on request for http exposure only
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: alias-http-route
  namespace: alias
spec:
  parentRefs:
    - name: gateway
      namespace: gateway
      sectionName: http 
  hostnames:
    - alias.promotesudbury.ca
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: prompt-user
      backendRefs:
        - name: prompt-user
          port: 80

---
#appended on request for https exposure only
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: alias-https-route
  namespace: alias
spec:
  parentRefs:
    - name: gateway
      namespace: gateway
      sectionName: https 
  hostnames:
    - alias.promotesudbury.ca
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: prompt-user
      backendRefs:
        - name: prompt-user
          port: 80 #no-trust requires valuesInile: change
```