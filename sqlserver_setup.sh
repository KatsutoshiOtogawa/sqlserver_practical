
SQLSERVER_PASSWORD=5pcse0t_zthmbvGxpugR

# install sqlserver
alternatives --config python
# If not configured, install python2 and openssl10 using the following commands: 
dnf install -y python2
dnf install -y compat-openssl10
# Configure python2 as the default interpreter using this command: 
alternatives --config python

curl -o /etc/yum.repos.d/mssql-server.repo https://packages.microsoft.com/config/rhel/8/mssql-server-2019.repo

dnf makecache

python3 << END
import pexpect

# Express is 3
Edition = 3
password = "$SQLSERVER_PASSWORD"


shell_cmd = "dnf install -y mssql-server"
prc = pexpect.spawn('/bin/bash', ['-c', shell_cmd],timeout=1200)

prc.expect("Enter your edition")
prc.sendline(Edition)

prc.expect("Do you accept the license terms")
prc.sendline("Yes")

prc.expect("Enter the SQL Server system administrator password")
prc.sendline(password)

prc.expect("Confirm the SQL Server system administrator password")
prc.sendline(password)

prc.expect( pexpect.EOF )
END

sudo firewall-cmd --zone=public --add-port=1433/tcp --permanent
sudo firewall-cmd --reload

systemctl stop mssql-server

# edit unit-files. for ODBC Driver 17 to SQL Server.
# (https://docs.microsoft.com/ja-jp/archive/blogs/sql_server_team/installing-sql-server-2017-for-linux-on-ubuntu-18-04-lts)
# systemctl edit mssql-server
mkdir /etc/systemd/system/mssql-server.service.d
cat << END >> /etc/systemd/system/mssql-server.service.d/override.conf
[Service]
Environment="LD_LIBRARY_PATH=/opt/mssql/lib" 

END

# create symbolic link to mssql-server library.
ln -s /usr/lib64/libssl.so.1.1 /opt/mssql/lib/libssl.so 
ln -s /usr/lib64/libcrypto.so.1.1 /opt/mssql/lib/libcrypto.so 

systemctl start mssql-server

curl -o /etc/yum.repos.d/msprod.repo https://packages.microsoft.com/config/rhel/8/prod.repo

dnf makecache

python3 << END
import pexpect

# Express is 3
Edition = 3
password = "$SQLSERVER_PASSWORD"


shell_cmd = "dnf install -y mssql-tools unixODBC-devel"
prc = pexpect.spawn('/bin/bash', ['-c', shell_cmd],timeout=1200)

prc.expect("Do you accept the license terms")
prc.sendline("Yes")

prc.expect("Do you accept the license terms")
prc.sendline("Yes")

prc.expect( pexpect.EOF )
END


echo 'export PATH=$PATH:/opt/mssql-tools/bin' >> ~/.bash_profile
echo 'export SQLSERVER_PASSWORD=$SQLSERVER_PASSWORD' >> ~/.bash_profile
source ~/.bash_profile

su - vagrant -c 'echo export PATH=\$PATH:/opt/mssql-tools/bin >> ~/.bash_profile'
su - vagrant -c "echo export SQLSERVER_PASSWORD=$SQLSERVER_PASSWORD>> ~/.bash_profile"
su - vagrant -c "echo ''>> ~/.bash_profile"

# install sample data [Microsoft](https://docs.microsoft.com/ja-jp/sql/samples/adventureworks-install-configure?view=sql-server-ver15&tabs=tsql)

curl -L -O https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorks2019.bak

sqlcmd -S localhost -U SA -P $SQLSERVER_PASSWORD << END
USE [master]
RESTORE DATABASE [AdventureWorks2019] 
FROM  DISK = N'./AdventureWorks2019.bak' 
WITH  FILE = 1,  NOUNLOAD,  STATS = 5
GO
END

curl -L -O https://github.com/Microsoft/sql-server-samples/releases/download/adventureworks/AdventureWorksDW2019.bak

USE [master]
RESTORE DATABASE [AdventureWorksDW2019] 
FROM  DISK = N'./AdventureWorksDW2019.bak' 
WITH  FILE = 1,  NOUNLOAD,  STATS = 5
GO