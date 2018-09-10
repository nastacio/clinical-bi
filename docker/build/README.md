# Secrets

The docker configuration requires you to have the following secret files available in a local directory on your machine.


## ~/etc/aact.properties

The file should look like this:

	[aact.database]
	dbname=aact
	user=<user>
	password=<password for user>
	host=<psql hostname>
	port=<psql port number>

For instance, if connecting to the AACT Cloud Database rather than deploying your own clone, 
first visit "https://aact.ctti-clinicaltrials.org/connect" and request an account, then
place those the credentials into the file. 

	[aact.database]
	dbname=aact
	user=<myuser>
	password=<mypassword>
	host=aact-db.ctti-clinicaltrials.org
	port=5432


## ~/etc/db2wh.aact.credentials.json 

These are the credentials to a DB2 Warehouse service instance in the IBM Cloud.

	{
	"hostname": "...",
	"password": "...",
	"https_url": "...",
	"port": 50000,
	"ssldsn": "...;Security=SSL;",
	"host": "...",
	"jdbcurl": "...",
	"uri": "...:50001/BLUDB",
	"db": "BLUDB",
	"dsn": "...;",
	"username": "...",
	"ssljdbcurl": "...;"
	}
	
	