require "chefspec"

::LOG_LEVEL = :fatal
::REDHAT_OPTS = {
  :platform => "redhat",
  :version => "6.3",
  :log_level => ::LOG_LEVEL
}
::UBUNTU_OPTS = {
  :platform => "ubuntu",
  :version => "12.04",
  :log_level => ::LOG_LEVEL
}

def block_storage_stubs
  ::Chef::Recipe.any_instance.stub(:config_by_role)
  ::Chef::Recipe.any_instance.stub(:config_by_role).
    with("rabbitmq-server", "queue").and_return(
      {'host' => 'rabbit-host', 'port' => 'rabbit-port'}
    )
  ::Chef::Recipe.any_instance.stub(:secret).
    with("secrets", "openstack_identity_bootstrap_token").
    and_return "bootstrap-token"
  ::Chef::Recipe.any_instance.stub(:db_password).and_return String.new
  ::Chef::Recipe.any_instance.stub(:user_password).and_return String.new
  ::Chef::Recipe.any_instance.stub(:service_password).and_return String.new
  ::Chef::Recipe.any_instance.stub(:service_password).with("cinder").
    and_return "cinder-pass"
end

def expect_runs_openstack_common_logging_recipe
  it "runs logging recipe if node attributes say to" do
    expect(@chef_run).to include_recipe "openstack-common::logging"
  end
end

def expect_creates_cinder_conf service, action=:restart
  describe "cinder.conf" do
    before do
      @file = @chef_run.template "/etc/cinder/cinder.conf"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "cinder", "cinder"
    end

    it "has proper modes" do
      expect(sprintf("%o", @file.mode)).to eq "644"
    end

    it "notifies service restart" do
      expect(@file).to notify service, action
    end
  end
end

def expect_creates_policy_json service, action=:restart
  describe "policy.json" do
    before do
      @file = @chef_run.template "/etc/cinder/policy.json"
    end

    it "has proper owner" do
      expect(@file).to be_owned_by "cinder", "cinder"
    end

    it "has proper modes" do
      expect(sprintf("%o", @file.mode)).to eq "644"
    end

    it "notifies service restart" do
      expect(@file).to notify service, action
    end
  end
end
