settings = Stash.settings(node)

database_connection = {
  :host => settings['database']['host'],
  :port => settings['database']['port']
}

case settings['database']['type']
when 'mysql'

  # compatible with both v5 and v6 of the mysql cookbook
  # read old mysql attributes but use mysql_service
  # resource instead of deprecated mysql::server recipe
  mysql_data_dir = node['mysql']['data_dir']
  unless mysql_data_dir
    case node['platform']
    when 'smartos'
      mysql_data_dir = '/opt/local/lib/mysql'
      node.default['mysql']['data_dir'] = mysql_data_dir
    else
      mysql_data_dir = '/var/lib/mysql'
      node.default['mysql']['data_dir'] = mysql_data_dir
    end
  end
  mysql_service_name = node['mysql']['service_name'] || 'default'
  mysql_port = node['mysql']['port'] || '3306'
  mysql_server_root_password = node['mysql']['server_root_password'] || 'ilikerandompasswords'
  mysql_service mysql_service_name do
    port mysql_port
    data_dir mysql_data_dir
    server_root_password mysql_server_root_password
    server_debian_password node['mysql']['server_debian_password']
    server_repl_password node['mysql']['server_repl_password']
    package_action 'install'
    action :create
  end

  include_recipe 'database::mysql'
  database_connection.merge!(:username => 'root', :password => node['mysql']['server_root_password'])

  mysql_database settings['database']['name'] do
    connection database_connection
    collation 'utf8_bin'
    encoding 'utf8'
    action :create
  end

  # See this MySQL bug: http://bugs.mysql.com/bug.php?id=31061
  mysql_database_user '' do
    connection database_connection
    host 'localhost'
    action :drop
  end

  mysql_database_user settings['database']['user'] do
    connection database_connection
    host '%'
    password settings['database']['password']
    database_name settings['database']['name']
    action [:create, :grant]
  end
when 'postgresql'
  include_recipe 'postgresql::server'
  include_recipe 'database::postgresql'
  database_connection.merge!(:username => 'postgres', :password => node['postgresql']['password']['postgres'])

  postgresql_database settings['database']['name'] do
    connection database_connection
    connection_limit '-1'
    encoding 'utf8'
    action :create
  end

  postgresql_database_user settings['database']['user'] do
    connection database_connection
    password settings['database']['password']
    database_name settings['database']['name']
    action [:create, :grant]
  end
end
