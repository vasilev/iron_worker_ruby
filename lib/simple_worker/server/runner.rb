# This is the file that gets executed on the server.


def init_database_connection(sw_config)
  if sw_config
    db_config = sw_config['database']
    if db_config
      @logger.info "Connecting to database using ActiveRecord..."
      require 'active_record'
      ActiveRecord::Base.establish_connection(db_config)
    end
  end
end

def get_class_to_run(class_name)
  runner_class = Kernel.const_get(class_name)
  return runner_class
end

def init_runner(runner_class, job_data)
  # ensure initialize takes no arguments
  init_arity = runner_class.instance_method(:initialize).arity
  if init_arity == 0 || init_arity == -1
    # good. -1 can be if it's not defined at all
  else
    raise InvalidWorkerError, "Worker initialize method must accept zero arguments."
  end
  runner = runner_class.new
  runner.instance_variable_set(:@job_data, job_data)
  runner.instance_variable_set(:@sw_config, job_data['sw_config'])
  runner.sw_set_data(job_data)
  runner
end

def init_worker_service_for_runner(job_data)
  SimpleWorker.configure do |config|
    sw_config = job_data['sw_config']
    config.access_key = sw_config['access_key']
    config.secret_key = sw_config['secret_key']
    #puts 'Setting host to ' + host.inspect
    config.host = sw_config['host'] if sw_config['host']
    db_config = sw_config['database']
    if db_config
      config.database = db_config
    end
    config.global_attributes = sw_config['global_attributes'] if sw_config['global_attributes']
  end
end

# Find environment (-e)
dirname = ""
i = 0
job_data_file = nil
puts "args for single file=" + ARGV.inspect
ARGV.each do |arg|
  if arg == "-d"
    # the user's writable directory
    dirname = ARGV[i+1]
  end
  if arg == "-j"
    # path to job data
    job_data_file = ARGV[i+1]
  end
  i+=1
end

# Change to user directory
puts 'dirname=' + dirname.inspect
Dir.chdir(dirname)

# Load in job data
job_data = JSON.load(File.open(job_data_file))
puts 'job_data=' + job_data.inspect

sw_config = job_data['sw_config']
init_database_connection(sw_config)

SimpleWorker.disable_queueing()
runner_class = get_class_to_run(job_data['class_name'])
SimpleWorker.running_class = runner_class
runner = init_runner(runner_class, job_data)
init_worker_service_for_runner(job_data)
SimpleWorker.enable_queueing()

# Let's run it!
runner_return_data = runner.run