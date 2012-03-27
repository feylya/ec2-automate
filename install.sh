#! /bin/bash


sudo yum -y update
sudo yum -y install make gcc gcc-c++ nginx mysql ruby-devel rubygems openssl-devel mysql-devel libxml2-devel libxslt libxslt-devel
bash -s stable < <(curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer)
source ~/.rvm/scripts/rvm
rvm install ruby-1.9.2-p290
rvm use 1.9.2
sudo gem install rdoc rake rails unicorn --no-rdoc --no-ri
sudo gem install nokogiri -v '1.5.0' --no-rdoc --no-ri
echo -e "server {
    listen       8000;
    listen       `curl -s http://169.254.169.254/latest/meta-data/public-hostname`:8080;
    server_name  `curl -s http://169.254.169.254/latest/meta-data/public-hostname`;

    location / {
        root   dashboard;
        index  index.html index.htm;
    }
}" | sudo tee -a /etc/nginx/conf.d/dashboard.conf

sudo /etc/init.d/nginx restart
sudo tar -xzvf ~/dashboard.tar.gz -C /usr/share/nginx/
cd /usr/share/nginx/dashboard
sudo cp ~/database.yml /usr/share/nginx/dashboard/config
sudo chown -R nginx:nginx *
sudo bundle install
sudo rake generate_session_store
sudo RAILS_ENV=production rake db:migrate