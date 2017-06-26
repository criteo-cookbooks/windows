class Chef
  class Provider
    class WindowsFeature
      module Base
        def whyrun_supported?
          true
        end

        def action_install
          if installed?
            Chef::Log.debug("#{@new_resource} is already installed - nothing to do")
          else
            converge_by "install windows feature #{@new_resource.featurename}" do
              install_feature(@new_resource.feature_name)
              Chef::Log.info("#{@new_resource} installed feature")
            end
          end
        end

        def action_remove
          if installed?
            converge_by "remove windows feature #{@new_resource.feature_name}" do
              remove_feature(@new_resource.feature_name)
              Chef::Log.info("#{@new_resource} removed")
            end
          else
            Chef::Log.debug("#{@new_resource} feature does not exist - nothing to do")
          end
        end

        def action_delete
          if available?
            converge_by "delete windows feature #{@new_resource.feature_name}" do
              delete_feature(@new_resource.feature_name)
              Chef::Log.info("#{@new_resource} deleted")
            end
          else
            Chef::Log.debug("#{@new_resource} feature is not installed - nothing to do")
          end
        end

        def install_feature(_name)
          raise Chef::Exceptions::UnsupportedAction, "#{self} does not support :install"
        end

        def remove_feature(_name)
          raise Chef::Exceptions::UnsupportedAction, "#{self} does not support :remove"
        end

        def delete_feature(_name)
          raise Chef::Exceptions::UnsupportedAction, "#{self} does not support :delete"
        end

        def installed?
          raise Chef::Exceptions::Override, "You must override installed? in #{self}"
        end

        def available?
          raise Chef::Exceptions::Override, "You must override available? in #{self}"
        end
      end
    end
  end
end
