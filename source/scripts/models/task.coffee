Base = require 'base'
List = require '../models/list'
Local = require '../controllers/local'
prettyDate = require '../utils/prettydate'

class Task extends Base.Model

  defaults:
    id: null
    listId: null
    date: null
    name: ''
    notes: ''
    priority: 1
    completed: false

  # Get the actual list
  list: =>
    List.get @listId

  prettyDate: =>
    date = if @date then new Date(@date) else null
    prettyDate(date)


###*
 * Basic collection of tasks for each list
###

class TaskCollection extends Base.Collection

  model: Task

  constructor: ->
    super

    # Cache the sorted tasks
    @sortCache = null

    # Destroy cache if contents change
    @on 'create:model change:model', =>
      @sortCache = null

    @on 'before:destroy:model', (task) =>
      index = @sortCache.indexOf task
      @sortCache.splice index, 1

  # Sort the tasks

  # < 0 :: a comes first
  # > 0 :: b comes first
  # = 0 :: no change

  sort: =>
    if @sortCache then return @sortCache
    @sortCache = @slice().sort (a, b) ->

      # If logged, move to bottom
      if a.completed is b.completed

        diff = b.priority - a.priority
        if diff is 0

          diff = (a.date or Infinity) - (b.date or Infinity)

          # Infinity - Infinity is NaN
          if isNaN(diff)
            a.name.localeCompare(b.name)
          else diff

        else diff

      else if a.completed and not b.completed then 1
      else if not a.completed and b.completed then -1
      else b.completed - a.completed

###*
 * Holds every task ever made
###

class TaskSingleton extends Base.Collection

  Collection: TaskCollection

  className: 'task'

  model: Task

  # Get the active tasks
  active: =>
    @filter (task) -> !task.completed

  # Get the completed tasks
  completed: =>
    @filter (task) -> task.completed

  # Get the matching tasks for a list
  list: (listId) =>
    return [] unless listId
    @filter (task) -> task.listId is listId



  # Search through tasks
  # - type (string) : can be 'all', 'active' or 'completed'
  search: (query, type='all') =>

    switch type
      when 'active'
        tasks = @active()
      when 'completed'
        tasks = @completed()
      when 'all'
        tasks = @all()

    return tasks unless query.length > 0
    query = query.toLowerCase().split ' '

    tasks.filter (item) ->
      for word in query
        if item.name.toLowerCase().indexOf(word) < 0 then return false
      return true

  # Find tasks with matching tags
  tag: (tag) =>
    return [] unless tag
    tag = tag.toLowerCase()
    @filter (item) ->
      item.name?.toLowerCase().indexOf('#'+tag) > -1

# Create a new TaskCollection to store all tasks
allTasks = new TaskSingleton()

# Add task to the list.task collection
allTasks.on 'create:model', (task) =>
  if List.exists task.listId
    list = task.list()
    list.tasks.add task

# Add localStorage support
new Local(allTasks)

module.exports = allTasks
