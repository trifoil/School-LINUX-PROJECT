# LINUX-SERVER-EXAM

dnf -y group install "Basic Desktop" GNOME 

startx

https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_networking_infrastructure_services/assembly_setting-up-and-configuring-a-bind-dns-server_networking-infrastructure-services#proc_configuring-bind-as-a-caching-dns-server_assembly_setting-up-and-configuring-a-bind-dns-server


https://www.server-world.info/en/note?os=Fedora_40&p=dns&f=1

## Structure

## Report 

## Hell yea 🤘

sudo nano /etc/resolv.conf



```
dnf install git -y                                                            
rm -rf git School-LINUX-PROJECT
git clone https://github.com/trifoil/School-LINUX-PROJECT.git
cd School-LINUX-PROJECT
sudo sh install.sh
curl http://main.test.toto
cd ..
```


http://test.toto
test.toto

ajouter le DNS dans nmtui sur la machine client

!!! redémarrer NetworkManager sur la machine client dans le cas où le serveur aurait été déconnecté !!!



ERROR 2002 (HY000): Can't connect to local server through socket '/var/lib/mysql/mysql.sock' (2)
ERROR 2002 (HY000): Can't connect to local server through socket '/var/lib/mysql/mysql.sock' (2)

ERROR 1146 (42S02) at line 1: Table 'roundcubemail.users' doesn't exist




smb user created
test.sh: line 366: maildirmake.dovecot: command not found
chown: cannot access '/home/joe/Maildir': No such file or directory
ERROR 1146 (42S02) at line 1: Table 'roundcubemail.users' doesn't exist
Relabeled /mnt/raid5_share from system_u:object_r:unlabeled_t:s0 to system_u:object_r:mnt_t:s0
Relabeled /mnt/raid5_web from system_u:object_r:unlabeled_t:s0 to system_u:object_r:httpd_sys_content_t:s0
Relabeled /mnt/raid5_web/lost+found from system_u:object_r:unlabeled_t:s0 to system_u:object_r:httpd_sys_content_t:s0
Relabeled /mnt/raid5_web/joe from unconfined_u:object_r:unlabeled_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
Relabeled /mnt/raid5_web/joe/index.php from unconfined_u:object_r:unlabeled_t:s0 to unconfined_u:object_r:httpd_sys_content_t:s0
User joe has been created with a mail account and a database.
Mail can be accessed at http://mail.joe.test.toto

### fedora mount nfs

```
mkdir /mnt/nfs
sudo mount -t nfs 192.168.1.102:/mnt/raid5_share /mnt/nfs
sudo umount /mnt/nfs
```

### fedora mount samba

si le username est joe

smb://192.168.1.102/joe/

### mail explanations

**Postfix** and **Dovecot** are both software packages commonly used in email server setups. Here's a brief overview of each:

### Postfix
- **Postfix** is a Mail Transfer Agent (MTA). It is responsible for routing and delivering email messages.
- It handles the sending and receiving of emails from other MTAs over the internet.
- Postfix is known for its performance, security, and ease of configuration.
- It typically listens on port 25 (SMTP) for incoming email and can relay messages to other MTAs or deliver them to local mailboxes.

### Dovecot
- **Dovecot** is an IMAP and POP3 server. It is responsible for providing access to email messages stored on the server.
- It allows users to retrieve their emails using email clients (like Outlook, Thunderbird, etc.) via IMAP or POP3 protocols.
- Dovecot is known for its high performance, security, and support for various mailbox formats.
- It typically listens on ports 143 (IMAP) and 110 (POP3), and their secure versions on ports 993 (IMAPS) and 995 (POP3S).

### How They Work Together
- **Postfix** handles the sending and receiving of emails.
- **Dovecot** allows users to access and manage their emails stored on the server.
- Together, they form a complete email server solution where Postfix handles the transport of emails and Dovecot handles the retrieval and management of emails.

### Example Configuration
A typical email server setup might involve:
- **Postfix** for SMTP (sending/receiving emails).
- **Dovecot** for IMAP/POP3 (retrieving emails).

This combination ensures that emails can be sent, received, and accessed by users efficiently and securely.



fstab manque les options de montage securité et quotas

ftp oubli du chroot

pas de cert autosigne pour lle ftp