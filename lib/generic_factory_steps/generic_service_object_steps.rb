Given /^a(|n) (.*) exists with attributes and saved as (.*)$/ do |plural, factory_name, variable_name, table|
  params = prepare_params_from_table(table.hashes)
  record = Factory.create factory_name.to_sym, params
  instance_variable_set("@#{variable_name}", record)
end

Then /^the (.*) (.*) should have$/ do |position, model_name, table|
  object = model_name.classify.constantize.order(:id).send(position)
  table.hashes.each do |param|
    compare_value(object, param)
  end
end
Then /^the (.*) should have attributes$/ do |model_name, table|
  object = model model_name
  table.hashes.each do |param|
    compare_value(object, param)
  end
end

Then /^(\d+) "(.*)" objects should be created$/ do |number, object|
  klass = object.singularize.classify
  klass.constantize.count.should == number.to_i
end

Then /^I should receive an error with response$/ do |table|
  json = ActiveSupport::JSON.decode @exception.response
  table.hashes.each do |error|
    json[error["error_on"]].should include(error["reason"])
  end
end

Then /^I should receive a service error with response$/ do |table|
  error_hash = @exception.errors_in_hash
  table.hashes.each do |error|
    error_hash[error["error_on"]].should include(error["reason"])
  end
end

Then /^I should(| not) create a (.*) service (.*) with$/ do |yes_no, service_name, class_name, table|
  klass = "#{service_name.classify}ServiceObjects::#{class_name.gsub(" ", "_").classify}".constantize
  first_row = table.hashes.first
  value = prepare_value(first_row)
  objects = klass.find(:all, :conditions => {first_row['field_name'] => value})
  if yes_no.blank?
    objects.size.should == 1
    object = objects[0]
    table.hashes.each do |param|
      real_value = object.send(param["field_name"])
      if param["matching"] == "containing"
        real_value.should include(param["value"])
      else
        real_value.should == prepare_value(param)
      end
    end
  else
    objects.size.should == 0
  end
end

def prepare_params_from_table(params_array)
  params_array.inject({}) do |result, row|
    result.merge!(row["field_name"] => prepare_value(row))
  end
end

def compare_value(object, param)
  expectation_value = prepare_value(param)
  actual_value = object.send(param["field_name"])
  if expectation_value.is_a?(Float)
    actual_value.should be_within(1e-8).of(expectation_value)
  elsif expectation_value.is_a?(Time)
    actual_value.should be_within(6).of(expectation_value)
  elsif param["type"] == "inclusion"
    actual_value.should include(expectation_value)
  else
    actual_value.should == expectation_value
  end
end

def prepare_value(param)
  object = create_model(param["value"]) if param["type"] =~ /^new factory object/
    object = model(param["value"]) if param["type"] =~ /^factory object/
    return [object] if param["type"] == "new factory object in array"
  return object if param["type"] == "factory object"
  return [ object ] if param["type"] == "factory object in array"
  return object.id if param["type"] == "factory object id"
  return param["value"].to_date if param["type"] == "date"
  return param["value"].to_time if param["type"] == "time"
  return param["value"].to_f if param["type"] == "money"
  return eval(param["value"]) if param["type"] == "eval"
  return param["value"]
end
