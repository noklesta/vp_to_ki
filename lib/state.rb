class State
  ROOT_SUBSTATE_SELECTOR = 'Model[displayModelType="State"]'
  NONROOT_SUBSTATE_SELECTOR = 'ChildModels > Model[displayModelType="Region"] > ' + 
    'ChildModels > Model[displayModelType="State"]'
  ROOT_INITIAL_PSEUDO_STATE_SELECTOR = 'Model[displayModelType="Initial Pseudo State"]'
  NONROOT_INITIAL_PSEUDO_STATE_SELECTOR = 'ChildModels > Model[displayModelType="Region"] > ' + 
    'ChildModels > Model[displayModelType="Initial Pseudo State"]'

  @@state_map = {}
  attr_reader :name, :initial_substate
  attr_accessor :transitions

  def self.add_transition(transition)
    @@state_map[transition.from_id].transitions << transition
  end
 
  def initialize(node, parent_state, level)
    @node = node    # The Nokogiri::XML::Node object representing this state
    @parent_state = parent_state
    @level = level  # The level in the state hierarchy (used for indentation)
    @name = @level == 0 ? 'rootState' : node['name']
    @substate_selector = @level == 0 ? ROOT_SUBSTATE_SELECTOR : NONROOT_SUBSTATE_SELECTOR
    @initial_pseudo_state_selector = @level == 0 ? ROOT_INITIAL_PSEUDO_STATE_SELECTOR :
      NONROOT_INITIAL_PSEUDO_STATE_SELECTOR

    @transitions = []
    @@state_map[@node['id']] = self if @level > 0

    find_substates
    find_actions
  end

  def path
    @path ||= (@parent_state && @parent_state.name != 'rootState') ?
      @parent_state.path + '.' + name : name
  end

  def [](key)
    @node[key]
  end

  def output
    str = Printer::STATE_START.evaluate(self)
    str += transitions_output unless @transitions.empty?
    str += substates_output unless @substates.empty?
    str += Printer::STATE_END.evaluate(self)
    str
  end

  ########
  private
  ########

  def find_substates
    @substates = []
    @node.>(@substate_selector).map do |substate_node|
      @substates << State.new(substate_node, self, @level + 1)
    end
    find_initial_substate
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

  def find_actions
    ['entry', 'exit'].each do |action_type|
      match = @node.>(%Q{ModelProperties > ModelProperty[name="#{action_type}"] > Model})
      unless match.empty?
        instance_variable_set("@#{action_type}_action", match.first['name'])
      end
    end
  end

  def indent
    @indent ||= "\t" * (@level + 1)
  end

  def transitions_output
    str = Printer::TRANSITIONS_COMMENT.evaluate(self)
    transition_strings = []
    @transitions.each do |transition|
      context = {
        :indent => indent,
        :name => transition.name,
        :action => transition.action,
        :dest_path => @@state_map[transition.to_id].path
      }
      transition_strings << Printer::TRANSITION.evaluate(context)
    end
    str += transition_strings.join(",\n\n") + ("\n")
    str
  end

  def substates_output
    str = Printer::SUBSTATES_COMMENT.evaluate(self)
    substate_strings = []
    @substates.each do |substate|
      substate_strings << substate.output
    end
    str += substate_strings.join(",\n\n") + ("\n")
    str
  end
end

