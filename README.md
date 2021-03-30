# aws_temp_saml_creds

Ruby script to get temporary AWS saml creds for programmatic access

- The script prompts for url to login to, username, and password(not displayed).
- After login it will prompt with a list of roles available to the user to assume. If only one role exists it's auto selected.
- After selection the script will display the environment variable commands for copy/pasting to shell based on the OS type.
- The script will prompt if you want to automatically copy to system clipboard

Adapted from python3 script at:
<https://awsiammedia.s3.amazonaws.com/public/sample/SAMLAPICLIADFS/0192721658_1562696757_blogversion_samlapi_python3.py>

<https://aws.amazon.com/blogs/security/how-to-implement-federated-api-and-cli-access-using-saml-2-0-and-ad-fs/>
