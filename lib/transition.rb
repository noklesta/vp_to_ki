class Transition
  TRANSITION_SELECTOR = 'Model[displayModelType="Transition"][name]'
  FROM_SELECTOR = 'ModelProperties > ModelRefProperty[name="from"] > ModelRef'
  TO_SELECTOR = 'ModelProperties > ModelRefProperty[name="to"] > ModelRef'
  ACTIVITY_SELECTOR = 'ModelProperties > ModelProperty > Model[displayModelType="Activity"]'

  attr_reader :name, :action

  def self.find_transitions
    $doc.css(TRANSITION_SELECTOR).each do |transition_node|
      State.add_transition(Transition.new(transition_node))
    end
  end

  def initialize(transition_node)
    @node = transition_node

    # A transition does not need to specify an action, but if it does, it can be specified
    # either as a string following a slash in the name of the transition, or by selecting
    # Name -> Effect -> Edit... and specifying it as the name there. In the latter case,
    # the action will be represented as a model with displayModelType="Activity" in the XML.
    @name, @action = @node['name'].split('/')
    unless @action
      matches = @node.>(ACTIVITY_SELECTOR)
      unless matches.empty?
        @action = matches.first['name']
      end
    end
    @name.strip!
    @action.strip! if @action
  end

  def from_id
    @from_id ||= @node.>(FROM_SELECTOR).first['id']
  end

  def to_id
    @to_id ||= @node.>(TO_SELECTOR).first['id']
  end

  def [](key)
    @node[key]
  end

end

