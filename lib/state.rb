class State
  # Finds one or more states
  STATE_SELECTOR = 'Model[displayModelType="State"]'

  # Finds the region(s) of a state. In Visual Paradigm, a state cannot have substates unless
  # it contains at least one region. If we find several regions, they will be interpreted
  # as concurrent substates. If we find only one region, it has no purpose in the statechart code,
  # so it will be ignored and its substates will become substates of the state containing
  # the region.
  REGION_SELECTOR = 'ChildModels > Model[displayModelType="Region"]'

  # Finds initial pseudo states. An initial pseudo state should have a
  # transition to the default state ('initialSubstate') of the containing state.
  INITIAL_PSEUDO_STATE_SELECTOR = 'Model[displayModelType="Initial Pseudo State"]'

  # Finds a history state, if one exists
  HISTORY_STATE_SELECTOR = 'Model[displayModelType$="History"]'

  @@state_map = {}
  attr_reader :name, :parent_state, :initial_substate
  attr_accessor :transitions

  def self.add_transition(transition)
    @@state_map[transition.from_id].transitions << transition
  end
 
  def initialize(node, parent_state, level, from_region = false)
    @node = node    # The Nokogiri::XML::Node object representing this state
    @parent_state = parent_state
    @level = level  # The level in the state hierarchy (used for indentation)
    @name = level == 0 ? 'rootState' : node['name']

    # If this is the root state, or if it is a state that is constructed from a
    # region node (i.e. it is a concurrent/orthogonal state), it has no region
    # child. Otherwise it does.
    region_selector = (level == 0 || from_region) ? nil : REGION_SELECTOR

    # The root state node (<Project>) has a Models child, while other states have
    # ChildModel children
    child_selector = level > 0 ? 'ChildModels' : 'Models'

    @substate_selector = [region_selector, child_selector, STATE_SELECTOR].compact.join(' > ')
    @initial_pseudo_state_selector =
      [region_selector, child_selector, INITIAL_PSEUDO_STATE_SELECTOR].compact.join(' > ')
    @history_state_selector =
      [region_selector, child_selector, HISTORY_STATE_SELECTOR].compact.join(' > ')

    @transitions = []
    @nontransition_events = []
    @@state_map[@node['id']] = self if level > 0

    find_substates
    find_actions
    find_constraints  # actually events that do not lead to state transitions
  end

  def path
    @path ||= (@parent_state && @parent_state.name != 'rootState') ?
      @parent_state.path + '.' + name : name
  end

  def [](key)
    @node[key]
  end

  def output
    parts = []
    str = Printer::STATE_START.evaluate(self)
    parts << nontransition_events_output unless @nontransition_events.empty?
    parts << transitions_output unless @transitions.empty?
    parts << substates_output unless @substates.empty?
    str += parts.join(",\n\n") + ("\n") unless parts.empty?
    str += Printer::STATE_END.evaluate(self)
    str
  end

  ########
  private
  ########

  def find_substates
    @substates = []
    regions = @node.>(REGION_SELECTOR)
    if regions.size > 1
      create_concurrent_states_from(regions)
    else
      create_substates
      find_initial_substate
      create_history_state
    end
  end

  def create_concurrent_states_from(regions)
    @substates_are_concurrent = true
    regions.each do |region_node|
      @substates << State.new(region_node, self, @level + 1, true)
    end
  end

  def create_substates
    @node.>(@substate_selector).each do |substate_node|
      @substates << State.new(substate_node, self, @level + 1)
    end
  end

  def find_initial_substate
    initial_pseudo_state_match = @node.>(@initial_pseudo_state_selector)
    unless initial_pseudo_state_match.empty?
      pseudo_state_id = initial_pseudo_state_match.first['id']

      # Find the transition that originates at the initial pseudo state, and then find
      # the node that the transition leads to - this will be the initial substate
      from_ref = $doc.css(%Q{Model[displayModelType="Transition"] > ModelProperties >} + 
        %Q{ModelRefProperty[name="from"] > ModelRef[id="#{pseudo_state_id}"]})
      if from_ref
        transition_node = from_ref.first.parent.parent.parent
        initial_substate_id = transition_node.>(Transition::TO_SELECTOR).first['id']
        @initial_substate = @@state_map[initial_substate_id]
      end
    end
  end

  def create_history_state
    match = @node.>(@history_state_selector)
    unless match.empty?
      @history_state = State.new(match.first, self, @level + 1)
    end
  end

  def find_actions
    ['entry', 'exit'].each do |action_type|
      match = @node.>(%Q{ModelProperties > ModelProperty[name="#{action_type}"] > Model})
      unless match.empty?
        instance_variable_set("@#{action_type}_action", match.first['name'])
      end
    end
  end

  # Since I could not find a built-in way in VP state diagrams to represent events
  # that do not lead to a state transition, I "abuse" constraints to do this.
  # Constraints allow us to simply place a text string within a state in the diagram.
  # If the string contains a slash, we interpret what comes before the slash as the name
  # of an event and what comes after it as the name of the function to call. If no slash
  # is found, the entire string is interpreted as both the name of the event and of the
  # function to call.
  def find_constraints
    matches = $doc.css(%Q{Model[displayModelType="Constraint"] > ModelProperties > } +
      %Q{ModelRefProperty[name="from"] > ModelRef[id="#{@node['id']}"]})
    matches.each do |match|
      register_nontransition_event(match)
    end
  end

  def register_nontransition_event(node)
    constraint_node = node.parent.parent.parent
    name, action = constraint_node['name'].split('/')
    action = name unless action  # identical if the constraint contains no slash
    name.strip!
    action.strip!

    @nontransition_events << {:name => name, :action => action}
  end

  def indent
    @indent ||= "\t" * (@level + 1)
  end

  def nontransition_events_output
    str = Printer::NONTRANSITIONS_COMMENT.evaluate(self)
    event_strings = []
    @nontransition_events.each do |event|
      context = {
        :indent => indent,
        :name => event[:name],
        :action => event[:action]
      }
      event_strings << Printer::NONTRANSITION_EVENT.evaluate(context)
    end
    str += event_strings.join(",\n\n")
    str
  end

  def transitions_output
    str = Printer::TRANSITIONS_COMMENT.evaluate(self)
    transition_strings = []
    @transitions.each do |transition|
      destination_state = @@state_map[transition.to_id]
      context = {
        :indent => indent,
        :name => transition.name,
        :action => transition.action,
      }
      if destination_state.name =~ /History$/
        context.merge!({:parent_path => destination_state.parent_state.path})
        transition_strings << Printer::HISTORY_TRANSITION.evaluate(context)
      else
        context.merge!({:dest_path => destination_state.path})
        transition_strings << Printer::TRANSITION.evaluate(context)
      end
    end
    str += transition_strings.join(",\n\n")
    str
  end

  def substates_output
    str = Printer::SUBSTATES_COMMENT.evaluate(self)
    substate_strings = []
    @substates.each do |substate|
      substate_strings << substate.output
    end
    str += substate_strings.join(",\n\n")
    str
  end
end

