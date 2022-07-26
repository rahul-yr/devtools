# This is a script to install and deploy code-server to your domain.
  - This enables you to access the vscode over the internet in a single click

## Prerequisites
  - Domain Name (Suggested Google Domains)
  - GCP or Azure or AWS Account

## Tech
  - Web server : Nginx
  - SSL : Let's encrypt
  - DNS Provider : Google Domains ( You are free to use any dns provider of your choice. But you need to update the script accordingly.)
  - Google Cloud Compute instance

> But for Google Domains you don't need to update any code.

## Update the variables below to match your environment
  DOMAIN_NAME="temp.rahuldev.in"  
  SUPPORT_EMAIL="temp@rahuldev.in"  
  VSCODE_LOGIN_PASSWORD="admin"  
  USING_GOOGLE_DNS=true  
  USERNAME="Google dns UserName"  
  PASSWORD="Google dns Password"  
