When 'the system processes jobs' do
  last_count = nil
  while Delayed::Job.count > 0 && Delayed::Job.count != last_count
    last_count = Delayed::Job.count
    Delayed::Worker.logger = nil
    worker = Delayed::Worker.new(:quiet => true)
    worker.work_off
  end
end

When /^the system processes "(.*)" jobs$/ do |method_name|
  Delayed::Worker.logger = nil
  worker = Delayed::Worker.new(:quiet => true)
  Delayed::Job.find_each(:conditions => { :method_name => 'method_name' }) do |dj|
    worker.run(dj)
  end
end

Then "all the jobs should be processed" do
  Delayed::Job.count.should == 0
end

Then /^there should be (\d+) jobs remaining$/ do |i|
  Delayed::Job.count.should == i.to_i
end
