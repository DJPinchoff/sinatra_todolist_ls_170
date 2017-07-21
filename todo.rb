require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed] }.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos  = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

before do
  session[:lists] ||= []
  @lists = session[:lists]
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  erb :lists, layout: :layout
end

# Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# Validate list index
def load_list(index)
  list = session[:lists][index] if index && session[:lists][index]
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# View specific Todo List
get "/lists/:index" do
  @list_index = params[:index].to_i
  @list = load_list(@list_index)

  if @list_index >= @lists.size
    session[:error] = "The specified list was not found."
    redirect "/lists"
  else
    erb :list, layout: :layout
  end
end

# Edit an existing todo list
get "/lists/:index/edit" do
  @list_index = params[:index].to_i
  @list = load_list(@list_index)
  erb :edit_list, layout: :layout
end

# Return an error message if the name is invalid. Return nil if valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

#Return an error message if the name is invalid. Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "The todo must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Update existing todo list
post "/lists/:index" do
  list_name = params[:list_name].strip
  index = params[:index].to_i
  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    @list_index = index
    @list = load_list(@list_index)
    erb :edit_list, layout: :layout
  else
    session[:lists][index][:name] = list_name
    session[:success] = "The list name has been modified."
    redirect "/lists/#{index}"
  end
end

# Delete a todo list
post "/lists/:index/destroy" do
  index = params[:index].to_i
  session[:lists].delete_at(index)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Add a new todo to a list
post "/lists/:list_index/todos" do
  @list_index = params[:list_index].to_i
  @list = load_list(@list_index)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: text, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_index}"
  end
end

# Remove todo from todo list
post "/lists/:list_index/todos/:todo_index/destroy" do
  @list_index = params[:list_index].to_i
  @list = load_list(@list_index)
  todo_index = params[:todo_index].to_i
  @list[:todos].delete_at(todo_index)

  session[:success] = "The todo has been deleted."
  redirect "/lists/#{@list_index}"
end

# Update the status of a todo
post "/lists/:list_index/todos/:todo_index" do
  @list_index = params[:list_index].to_i
  @list = load_list(@list_index)
  todo_index = params[:todo_index].to_i

  is_completed = params[:completed] == "true"
  @list[:todos][todo_index][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_index}"
end

# Update the status to completed for all todo items on a list
post "/lists/:list_index/complete_all" do
  @list_index = params[:list_index].to_i
  @list = load_list(@list_index)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_index}"
end
