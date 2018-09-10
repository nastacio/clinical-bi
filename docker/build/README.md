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
	"hostname": "dashdb-entry-yp-dal09-09.services.dal.bluemix.net",
	"password": "_kSx4W0_hCxK",
	"https_url": "https://dashdb-entry-yp-dal09-09.services.dal.bluemix.net:8443",
	"port": 50000,
	"ssldsn": "DATABASE=BLUDB;HOSTNAME=dashdb-entry-yp-dal09-09.services.dal.bluemix.net;PORT=50001;PROTOCOL=TCPIP;UID=dash9184;PWD=_kSx4W0_hCxK;Security=SSL;",
	"host": "dashdb-entry-yp-dal09-09.services.dal.bluemix.net",
	"jdbcurl": "jdbc:db2://dashdb-entry-yp-dal09-09.services.dal.bluemix.net:50000/BLUDB",
	"uri": "db2://dash9184:_kSx4W0_hCxK@dashdb-entry-yp-dal09-09.services.dal.bluemix.net:50000/BLUDB",
	"db": "BLUDB",
	"dsn": "DATABASE=BLUDB;HOSTNAME=dashdb-entry-yp-dal09-09.services.dal.bluemix.net;PORT=50000;PROTOCOL=TCPIP;UID=dash9184;PWD=_kSx4W0_hCxK;",
	"username": "dash9184",
	"ssljdbcurl": "jdbc:db2://dashdb-entry-yp-dal09-09.services.dal.bluemix.net:50001/BLUDB:sslConnection=true;"
	}
	
	