module Citier
  module ChildInstanceMethods

    def save(validate = true)
      return false unless self.valid?
    
      #citier_debug("Callback (#{self.inspect})")
      citier_debug("SAVING #{self.class.to_s}")
    
      #Just run before save callbacks
      #AIT NOTE: Will change any protected values back to original values so any models onwards won't see changes.
      self.run_callbacks(:save){ false }
    
      #get the attributes of the class which are inherited from it's parent.
      attributes_for_parent = self.attributes.reject { |key,value| !self.class.superclass.column_names.include?(key) }
      changed_attributes_for_parent = self.changed_attributes.reject { |key,value| !self.class.superclass.column_names.include?(key) }

      # Get the attributes of the class which are unique to this class and not inherited.
      attributes_for_current = self.attributes.reject { |key,value| self.class.superclass.column_names.include?(key) }
      changed_attributes_for_current = self.changed_attributes.reject { |key,value| self.class.superclass.column_names.include?(key) }

      citier_debug("Attributes for #{self.class.superclass.to_s}: #{attributes_for_parent.inspect}")
      citier_debug("Changed attributes for #{self.class.superclass.to_s}: #{changed_attributes_for_parent.keys.inspect}")
      citier_debug("Attributes for #{self.class.to_s}: #{attributes_for_current.inspect}")
      citier_debug("Changed attributes for #{self.class.to_s}: #{changed_attributes_for_current.keys.inspect}")

      ########
      #
      # Parent saving
    
      #create a new instance of the superclass, passing the inherited attributes.
      parent = self.class.superclass.new
      
      parent.force_attributes(attributes_for_parent, :merge => true)
      changed_attributes_for_parent["id"] = 0 # We need to change at least something to force a timestamps update.
      parent.force_changed_attributes(changed_attributes_for_parent)
      
      parent.id = self.id if id
      parent.type = self.type
    
      parent.is_new_record(new_record?)
      
      # If we're root (AR subclass) this will just be saved as normal through AR. If we're a child it will call this method again. 
      # It will try and save it's parent and then save itself through the Writable constant.
      parent_saved = parent.save
      self.id = parent.id

      if(parent_saved==false)
        # Couldn't save parent class
        # TODO: Handle situation where parent class could not be saved
        citier_debug("Class (#{self.class.superclass.to_s}) could not be saved")
      end
    
      #End of parent saving
    
      ######
      ##
      ## Self Saving
      ##

      # If there are attributes for the current class (unique & not inherited) 
      # and parent(s) saved successfully, save current model
      if(!attributes_for_current.empty? && parent_saved)
       
        current = self.class::Writable.new
        
        current.force_attributes(attributes_for_current, :merge => true)
        current.force_changed_attributes(changed_attributes_for_current)
        
        current.id = self.id
        current.is_new_record(new_record?)
      
        current_saved = current.save
      
        #self.run_callbacks(:save){ false } #Run the after save callback
        # Rails 3 doesn't yet have a way of only called AFTER save callback
        current.after_save_change_request if current.respond_to?('after_save_change_request') #Specific to an app I'm building
      
        # This is no longer a new record
        is_new_record(false)

        if(!current_saved)
          citier_debug("Class (#{self.class.superclass.to_s}) could not be saved")
          citier_debug("Errors = #{current.errors.to_s}")
        end
      end

      if parent_saved && current_saved
        self.force_changed_attributes({})
      end
      
      return parent_saved && current_saved
    end
  
    def save!
      raise ActiveRecord::RecordInvalid.new(self) unless self.valid?
      self.save
    end
  
  

    include InstanceMethods
  end
end