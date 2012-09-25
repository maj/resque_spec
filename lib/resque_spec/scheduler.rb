require 'resque_spec'

module ResqueSpec
  module SchedulerExt
    def self.extended(klass)
      if klass.respond_to? :enqueue_at
        klass.instance_eval do
          alias :enqueue_at_without_resque_spec :enqueue_at
          alias :enqueue_in_without_resque_spec :enqueue_in
          alias :enqueue_at_with_queue_without_resque_spec :enqueue_at_with_queue
          alias :enqueue_in_with_queue_without_resque_spec :enqueue_in_with_queue
          alias :remove_delayed_without_resque_spec :remove_delayed
        end
      end
      klass.extend(ResqueSpec::SchedulerExtMethods)
    end
  end

  module SchedulerExtMethods
    def enqueue_at(time, klass, *args)
      return enqueue_at_without_resque_spec(time, klass, *args) if ResqueSpec.disable_ext && respond_to?(:enqueue_at_without_resque_spec)

      ResqueSpec.enqueue_at(time, klass, *args)
    end

    def enqueue_at_with_queue(queue, time, klass, *args)
      return enqueue_at_with_queue_without_resque_spec(queue, time, klass, *args) if ResqueSpec.disable_ext && respond_to?(:enqueue_at_with_queue_without_resque_spec)

      ResqueSpec.enqueue_at_with_queue(queue, time, klass, *args)
    end

    def enqueue_in(time, klass, *args)
      return enqueue_in_without_resque_spec(time, klass, *args) if ResqueSpec.disable_ext && respond_to?(:enqueue_in_without_resque_spec)

      ResqueSpec.enqueue_in(time, klass, *args)
    end

    def enqueue_in_with_queue(queue, time, klass, *args)
      return enqueue_in_with_queue_without_resque_spec(queue, time, klass, *args) if ResqueSpec.disable_ext && respond_to?(:enqueue_in_with_queue_without_resque_spec)
      ResqueSpec.enqueue_in_with_queue(queue, time, klass, *args)
    end

    def remove_delayed(klass, *args)
      return remove_delayed_without_resque_spec(klass, *args) if ResqueSpec.disable_ext && respond_to?(:remove_delayed_without_resque_spec)

      ResqueSpec.remove_delayed(klass, *args)
    end
  end

  def enqueue_at(time, klass, *args)
    enqueue_at_with_queue(queue_name(klass), time, klass, *args)
  end

  def enqueue_at_with_queue(queue_name, time, klass, *args)
    is_time?(time)
    perform_or_store(schedule_queue_name(queue_name), :class => klass.to_s, :time  => time, :stored_at => Time.now, :args => args)
  end

  def enqueue_in(time, klass, *args)
    enqueue_in_with_queue(queue_name(klass), time, klass, *args)
  end

  def enqueue_in_with_queue(queue_name, time, klass, *args)
    enqueue_at_with_queue(queue_name, Time.now + time, klass, *args)
  end

  def remove_delayed(klass, *args)
    count_removed = 0
    queues.each do |queue_name, queue_contents|
      if queue_name =~ /_scheduled$/
        count_before_remove = queue_contents.length
        queue_contents.delete_if do |job|
          job[:class] == klass.to_s && job[:args] == args
        end
        # Return number of removed items to match Resque Scheduler behaviour
        count_removed += (count_before_remove - queue_contents.length)
      end
    end
    count_removed
  end

  def schedule_for(klass)
    schedule_for_queue(queue_name(klass))
  end

  def schedule_for_queue(queue_name)
    queue_by_name(schedule_queue_name(queue_name))
  end

  private

  def is_time?(time)
    time.to_i
  end

  def schedule_queue_name(queue_name)
    "#{queue_name}_scheduled"
  end
end

Resque.extend(ResqueSpec::SchedulerExt)
