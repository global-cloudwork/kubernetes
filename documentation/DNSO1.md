gcloud certificate-manager dns-authoriza
tions create dns-auth --domain="promotesudbury.ca"

Using a wildcard SSL certificate can be super handy:

- **_Performant_**- some Subject Alternative Name (SAN) certificates can support upwards of 100 hostnames which can impact time-to-first-byte (TTFB) for a client browser. By using a wildcard hostname value, you don’t need to search through a lengthy list of subject alternative Fully Qualified Domain Name (FQDN) values in the SSL certificate chain.
- **_Secure_**- the content provider doesn’t need to list all hostnames that are in service. Sometimes, content providers will list QA and staging hostnames in a Subject Alternative Name SSL certificate chain which could expose a potential attack vector where a bad actor could attempt to exploit this loophole.
- **_Simplified Maintenance_**- you don’t need to manage multiple SSL certificates and different renewal times

![](https://miro.medium.com/v2/resize:fit:372/1*rn25L3Y8UnKOfPAt1UGrlA.png)

Wildcard issued by Google Trust Services

## Problem

Google Cloud enables its customers to issue Google managed SSL certificates that can be deployed against the [Google Global Load Balancer](https://cloud.google.com/load-balancing/docs/https) (GCLB) and the [Media CDN](https://cloud.google.com/media-cdn/docs/overview?hl=en) service offering. The official [Certificate Manager](https://cloud.google.com/certificate-manager/docs/domain-authorization#dns-auth) documentation talks about how you can use the new DNS-01 authentication process to issue a wildcard certificate, yet there is no step-by-step guidance on how to specifically issue a wildcard SSL certificate.

## Solution

Unlike Google Cloud’s previous SSL certificate process where you needed to point your FQDN directly at the Google IP address before the Google Trust Services (Google’s Certificate Authority service) would issue a SSL certificate, the new Google Cloud Certificate Manager service allows you to pre-issue a SSL certificate using a DNS certification process, known as DNS-01 authorization (challenge). This guide will walk you through the process of generating a wildcard SSL certificate on Google Cloud using the new DNS-01 auth process. There are 3 main steps in issuing a wildcard certificate using the Google Certificate Manager:

1. [Validate domain ownership via DNS](https://medium.com/@reisfeld/wildthing-i-think-i-love-you-2caa32572d24#ce48)
2. [Generate the SSL certificate](https://medium.com/@reisfeld/wildthing-i-think-i-love-you-2caa32572d24#04a0)
3. [Bind the SSL certificate to the Google Cloud Global Load Balancer](https://medium.com/@reisfeld/wildthing-i-think-i-love-you-2caa32572d24#5797)

## 1) Validate Domain Ownership

In order to prove ownership of your domain, Google Cloud looks at your DNS — the notion is if you can manipulate your DNS zone records, you must be the owner of the hostname.

The “old” method that Google used is that you would have to point your FQDN in your DNS record at the Google IP address of the Global Load Balancer and once Google Trust Services, the Certificate Authority service, can see that your hostname is pointed at the Google assigned IP address, that would act as verification and Google Cloud would issue the SSL certificate. A problem arises in that if you have a live domain serving production traffic, the SSL certificate could not be pre-issued; therefore, there could be a period of downtime or service interruption since the SSL certificate issuance process can take upwards of an hour.

## DNS-01 Authentication

To address the shortcoming of validating the hostname for the SSL certificate by pointing your hostname at the production Google IP address, content providers can now pre-issue SSL certificates using a separate DNS record value as a way of validating ownership of your hostname. This process is called DNS-01 authentication. Some refer to it as the DNS-01 challenge- it is basically the same thing.

## Before you begin

Before you get started, you will want to make sure that you have:

A) [Set your default project](https://medium.com/@reisfeld/wildthing-i-think-i-love-you-2caa32572d24#3c23)

B) [Ensure you have IAM permissions to Certificate Manager](https://medium.com/@reisfeld/wildthing-i-think-i-love-you-2caa32572d24#b411)

C) [Enabled Certificate Manager API](https://medium.com/@reisfeld/wildthing-i-think-i-love-you-2caa32572d24#06c5)

### A) Setting your project

The method of setting your default project will vary depending on whether you are using the Google Cloud console or the command line tools via GCLOUD.

**Google Cloud Console**

1. In your browser, go to the Home page of the Google Cloud console: [https://console.cloud.google.com](https://console.cloud.google.com/).
2. Once on the Home page, to the right of Google Cloud, select a project from the pull-down menu and select the project that you will use for your Cloud CDN instance.

**GCLOUD commands via Cloud Shell**

For demonstration purposes, I am going to use the built-in shell access within the Google Cloud console. Log into your Google Cloud console. In the upper right hand corner of the navigation menu, click on the Cloud Shell icon to launch Cloud Shell.

![](https://miro.medium.com/v2/resize:fit:646/0*p5qtCKFsCnCqLCHw)

Open Cloud Shell in Google Cloud Console

If you selected the project in the Google Cloud console and then launch the Cloud Shell application, it should default to the current project. If you aren’t sure, you need to set your project before configuring the HTTP redirection action.

1. List all projects in your organization that you have access to:

gcloud projects list

Example output:

+ — — — — — — — — + — — — — — — — — -+ — — — — — — — — +  
| PROJECT_ID    | NAME            | PROJECT_NUMBER |  
+ - - - - - - - - + - - - - - - - - -+ - - - - - - - - +  
| covid-id-123  | covid-emergency | 4270496XXXX    |  
| prueba-perf   | prueba-perf     | 3220824XXXX    |  
| test-job-2a-0 | test-job-2a-0   | 72148XXXXXX    |  
+ - - - - - - - - + - - - - - - - - -+ - - - - - - - - +

Take the name of the Project ID value that will be hosting your Cloud CDN instance and run the following command to set the Cloud Shell project:

gcloud config set project [Project_ID]

Example Output:

gcloud config set project covid-id-123

B) IAM permissions for Certificate Manager

If you are an admin or owner of your project, in all likelihood you already have [permissions to use the Certificate Manager service](https://cloud.google.com/certificate-manager/docs/permissions). If you find that you cannot run the Certificate Manager commands, you need to have the following permissions added to your Google Cloud user in order to execute the SSL certificate issuance process:

- certificatemanager.certs.create  
- certificatemanager.certs.get  
- certificatemanager.certs.list  
- certificatemanager.certs.use  
- certificatemanager.dnsauthorizations.create  
- certificatemanager.dnsauthorizations.get  
- certificatemanager.dnsauthorizations.list  
- certificatemanager.dnsauthorizations.use

C) Enable Certificate Manager API

Run the following command in your Cloud Shell instance to enable the Certificate Manager functionality. This will allow you to generate SSL certificates using the DNS-based authorization process.

gcloud services enable certificatemanager.googleapis.com

## Generate DNS Authorization Request

The first step of issuing a wildcard certificate is to generate a DNS Authorization request. There is no GUI console support today, so I’ll walk you through the gCloud command lines that you will run in your Cloud Shell instance. When you issue a DNS authorization request, you need to make the request against the apex (example.com) or top-level subdomain (foobar.example.com) that you want to issue the SSL certificate against. This is important in that even though we want to issue a wildcard certificate, we are going to authorize the root hostname value which will serve as the basis of our wildcard hostname.

Input:

gcloud certificate-manager dns-authorizations create DOMAIN_NAME_AUTH \  
--domain="DOMAIN_NAME"

- DOMAIN_NAME_AUTH = the Google Cloud name that you will refer to the DNS authorization
- DOMAIN_NAME= the apex or subdomain you want to issue the wildcard certificate against

Example:

gcloud certificate-manager dns-authorizations create example-com-authorization \  
--domain="example.com"

When you first execute the gCloud command for the Certificate Manager, you may get a prompt asking you to Authorize Cloud Shell to execute the command. Click on `AUTHORIZE`.

Output:

Waiting for operation [projects/sample-project/locations/global/operations/operation-167xxxxxx46–5f2668ff52470–7de06f35–71b4fb7b] to complete…done.  
Created dnsAuthorization [example-com-authorization].

## Create CNAME Value in DNS Zone File

At this point, the DNS authorization request has been generated, but you now need to make a DNS entry in your zone file where the Google Trust Services will validate ownership of the domain. To get the validation value you need to enter in your resource record, run the following command:

gcloud certificate-manager dns-authorizations describe DOMAIN_NAME_AUTH

Where the DOMAIN_NAME_AUTH is the Google Cloud name that you used to generate the DNS authorization request in the previous step

Example:

gcloud certificate-manager dns-authorizations describe example-com-authorization

Output:

createTime: '2023–01–16T19:26:39.487925614Z'  
dnsResourceRecord:  
data: 011c6e14–1880-xxxxxxxxxxxxxxxx.9.authorize.certificatemanager.goog.  
name: _acme-challenge.example.com.  
type: CNAME  
domain: example.com  
name: projects/sample-project/locations/global/dnsAuthorizations/example-com-authorization

You will create a resource entry in your DNS zone file that will point to the data value. The data value is what Google Trust Services is going to look for as proof that you own the domain.

Resource host (from the name line): _acme-challenge.example.com.  
Record Type: CNAME  
TTL: 60  
Target value (from the data line): 011c6e14–1880-xxxxxxxxxxxxxxxx.9.authorize.certificatemanager.goog.

Customers can use a wide variety of DNS hosting services, so for the sake of brevity, I won’t go through the process of adding a resource record in the resolver.

## Get David Reisfeld’s stories in your inbox

Join Medium for free to get updates from this writer.

Some DNS-01 Auth services use a TXT file entry. Google Cloud uses a CNAME record type.

> If you enter a TXT record type, Google Cloud will **_not_** validate your domain- it is specifically looking for a CNAME record value.

You can check to see if your acme-challenge value is being advertised properly by using an [online DIG](https://toolbox.googleapps.com/apps/dig/#CNAME/) tool.

## 2) Initiate the SSL Certificate Request

Do not run this step until you have entered the DNS-01 authorization value in your DNS zone file. If you proceed to generate the SSL certificate request ahead of the DNS entry, it will delay the issuance of your SSL certificate. Google Trust Services will attempt to immediately validate your hostname when you trigger the SSL certificate request.

> If the acme-challenge value is not already in place, the Google Trust Services platform will keep trying to validate your domain; however, it will add a backoff time and continue to increase the backoff time if it encounters repeated validation failures which will delay the issuance of the SSL certificate.

Input:

gcloud certificate-manager certificates create CERTIFICATE_NAME \  
--domains="DOMAIN_NAME" \  
--domains="DOMAIN_NAME" \  
--dns-authorizations="DOMAIN_NAME_AUTH" \  
--scope=[DEFAULT | EDGE_CACHE]

- CERTIFICATE_NAME= this is the internal Google Cloud name that you will refer to for the wildcard SSL certificate
- DOMAIN_NAME: you will list this value twice, once will be the root hostname. The second value will be the wildcard version of the hostname. **It is VERY important that you list the root hostname first and the wildcard hostname second.**
- DOMAIN_NAME_AUTH: this is the friendly name that you used in step 1 to trigger the DNS authorization request. You need to tell Google Cloud what record to use to find the DNS-01 Auth value for the verification process.
- SCOPE: by default, the SCOPE will always be the Global Load Balancer. If you don’t specify anything in your scope, it will assume you want the SSL certificate to be issued in support of your load balancer. When you issue the SSL certificate for the purpose of being used against the [Media CDN](https://cloud.google.com/media-cdn/docs/overview?hl=en) service, you need to specifically issue the SSL certificate scope against edge_cache.

Example:

gcloud certificate-manager certificates create wildcard-example-com \  
--domains="example.com" \  
--domains="*.example.com" \  
--dns-authorizations="example-com-authorization" \  
--scope=default

Output:

Create request issued for: [wildcard-example-com]  
Waiting for operation [projects/sample-project/locations/global/operations/operation-167389 to complete…working.  
Waiting for operation [projects/sample-project/locations/global/operations/operation-167389] to complete…done.  
Created certificate [wildcard-example-com].

This triggers the SSL certificate generation process. If your DNS-01 Auth value is already in place, it can take 5–15 minutes to generate the SSL certificate.

To see if the SSL certificate has been issued, run the following command:

Input:

gcloud certificate-manager certificates describe CERTIFICATE_NAME

- CERTIFICATE_NAME: this is the friendly name value you used in the previous step to generate the SSL certificate.

Example:

gcloud certificate-manager certificates describe wildcard-example-com

Output:

createTime: ‘2023–01–16T20:02:15.979049311Z’  
managed:  
authorizationAttemptInfo:  
- domain: '*.example.com'  
state: AUTHORIZED  
dnsAuthorizations:  
- projects/6618550859/locations/global/dnsAuthorizations/foobar-authoriazation  
domains:  
- '*.example.com'  
state: ACTIVE  
name: projects/sample-project/locations/global/certificates/wildcard-example-com  
sanDnsnames:  
- '*.example.com'

You need to wait for the state to say AUTHORIZED and ACTIVE. You will not be able to bind your new wildcard certificate to your Load Balancer if the actual SSL certificate has not been issued.

SSL certificates can be issued against the Global Load Balancer or Media CDN. Unfortunately, if you make a mistake and issue your wildcard certificate against the wrong scope type, you can’t just update the scope. You will need to delete the SSL certificate and re-issue the certificate using the correct scope. The good news is that you don’t need to change your DNS-01 authorization; rather, you just need to re-issue the SSL certificate with the proper scope.

gcloud certificate-manager certificates delete wildcard-example-com

Confirm you want to delete the SSL certificate entry, and re-issue the previous command to request the SSL certificate with the proper scope.

> SSL certificates are per Google Cloud project and are not an organizational object.

## 3) Binding Your Wildcard SSL Certificate to your GCLB

For the purposes of this tutorial, I am not going to discuss the process of [setting up a Google Global Load Balancer](https://cloud.google.com/load-balancing/docs/https/ext-https-lb-simple). I am going to assume that you already have a load balancer in place and we are just going to [add the newly issued wildcard certificate to your load balancer](https://cloud.google.com/certificate-manager/docs/deploy-google-managed-lb-auth#deploy_the_certificate_to_a_load_balancer) instance.

As with the Certificate Manager, the process of attaching a wildcard certificate using DNS-01 auth can only be done via command line.

Input:

gcloud certificate-manager maps create CERTIFICATE_MAP_NAME

- CERTIFICATE_MAP_NAME: this is the internal Google Cloud name that you will reference when attaching the certificate map to your GCLB frontend.

Example:

gcloud certificate-manager maps create example-com-ssl-map

Output:

Waiting for ‘operation-1673903754202-xxxxxxf’ to complete…done.  
Created certificate map [example-com-ssl-map].

Associate the SSL map with the SSL certificate you created earlier in the process.

Input:

gcloud certificate-manager maps entries create CERTIFICATE_MAP_ENTRY_NAME \  
--map="CERTIFICATE_MAP_NAME" \  
--certificates="CERTIFICATE_NAME" \  
--hostname="HOSTNAME"

- CERTIFICATE_MAP_ENTRY_NAME is a unique name that describes this certificate map entry.
- CERTIFICATE_MAP_NAME is the name of the certificate map to which this certificate map entry attaches.
- CERTIFICATE_NAME is the name of the certificate you want to associate with this certificate map entry.
- HOSTNAME is the hostname that you want to associate with this certificate map entry

If you forgot your certificate name, you can run the following command to get a list of certificates on your project:

gcloud certificate-manager certificates list

Example:

gcloud certificate-manager maps entries create gclb-ssl-map \  
--map="example-com-ssl-map" \  
--certificates="wildcard-example-com" \  
--hostname="*.example.com"

Output:

Waitingo for operation-1673904158779-xxxxx’ to complete…done.  
Created certificate map entry [gclb-ssl-map].

It can take upwards of 5 minutes for the GCLB SSL map to be created. Before you can bind the map to your frontend attachment on your GCLB, the map must be `ACTIVE`. To check this, run the following command:

gcloud certificate-manager maps entries describe gclb-ssl-map \  
--map="example-com-ssl-map"

Output:

certificates:  
- projects/668154879xx/locations/global/certificates/wildcard-example-com  
createTime: '2023–01–16T21:22:38.977696786Z'  
hostname: '*.example.com'  
name: projects/sample-project/locations/global/certificateMaps/example-com-ssl-map/certificateMapEntries/gclb-ssl-map  
state: ACTIVE  
updateTime: '2023–01–16T21:22:39.396013065Z'

To complete this maneuver, you need to know the name of your HTTPS frontend. You can look this up in the console under Load Balancer. Alternatively, you can run the following command to list all your HTTPS frontends:

Input:

gcloud compute target-https-proxies list

Output (your output may vary):

NAME: example-gclb-target-proxy  
SSL_CERTIFICATES: www-shopvoxpopulus-com  
URL_MAP: example-gclb  
CERTIFICATE_MAP:

Notice that the `CERTIFICATE_MAP` is blank. This means that we have not bound our SSL Certificate map to the frontend.

We are now going to attach the certificate map by running the following command:

Input:

gcloud compute target-https-proxies update PROXY_NAME \  
--certificate-map="CERTIFICATE_MAP_NAME"

- PROXY_NAME is the name of the target proxy.
- CERTIFICATE_MAP_NAME is the name of the certificate map referencing your certificate map entry and its associated certificate that you previously created.

Example:

gcloud compute target-https-proxies update example-gclb-target-proxy \  
--certificate-map="example-com-ssl-map"

Output:

Updated [https://www.googleapis.com/compute/v1/projects/sample-project/global/targetHttpsProxies/example-gclb-target-proxy].

It can take up to 30 minutes for the new certificate to be available on your Global Load Balancer.

Phew- a long process, but you now can generate a wildcard certificate, pre-deploy it before going into production, and the your wildcard certificate will auto new so long as you leave the DNS-01 auth value in place.

If you have questions about Google Cloud, Cloud CDN, or Media CDN, contact your Google Cloud Sales team or reach out to me via the [Google Cloud Community Slack channel](https://googlecloud-community.slack.com/) and post a note in the #cloud-cdn channel. Alternatively, you can post your questions in the [Google Cloud Stackoverflow channel](https://stackoverflow.com/questions/tagged/google-cloud-cdn).