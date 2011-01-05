class Transition
  TRANSITION_SELECTOR = 'Model[displayModelType="Transition"][name]'
  FROM_SELECTOR = 'ModelProperties > ModelRefProperty[name="from"] > ModelRef'
  TO_SELECTOR = 'ModelProperties > ModelRefProperty[name="to"] > ModelRef'

  def self.find_transitions
    $doc.css(TRANSITION_SELECTOR).each do |transition_node|
      State.add_transition(Transition.new(transition_node))
    end
  end

  def initialize(transition_node)
    @node = transition_node
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

