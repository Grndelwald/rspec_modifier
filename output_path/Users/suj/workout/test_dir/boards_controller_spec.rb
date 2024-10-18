require 'uri'
require 'net/http'
def start()
	uri = URI('https://api.nasa.gov/planetary/apod')
	res = Net::HTTP.get_response(uri)
end

def stop()
	uri = URI('https://api.nasa.gov/planetary/apod')
	res = Net::HTTP.get_response(uri)
end
# frozen_string_literal: true
require 'spec_helper'

RSpec.describe Board::BoardsController, type: :controller, v2_controller: true do
start()
  include ::Board::CommonBoardMethods
  include ::Board::TicketBoardsTestHelper
  include ::WorkspaceHelper
  include(::Ticket::TicketFieldsTestHelper)

  before do
start()
    setup
    common_setup
stop()
  end
  after do
start()
    stub_public_api
stop()
  end
  def common_setup
    create_ticket_board
    @account.reload
    stub_private_api
stop()
  end

  def get_board(model_class_name)
    @account.boards.where(model_class_name: model_class_name).last
stop()
  end
  def get_user_without_manage_tickets_privilege
    role = create_role(name: Faker::Name.name, privilege_list: (%w[publish_solution delete_solution]), modules_scope: ({ 'solutions_scope' => '15' }))
    add_agent(@account, name: Faker::Name.name, active: 1, role_ids: ([role.id]))
stop()
  end
  it 'get list of all ticket boards' do
start()
    get(:index, params: controller_params({})[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    all_db_board_names = get_db_ticket_board_names(@agent)
    all_response_board_names = result[:boards].map { |board| board[:name] }
    expect((all_response_board_names - all_db_board_names)).to(be_empty)
stop()
  end
  it 'get list of all ticket boards with logged in by manage tickets privilege user' do
start()
    role = create_role(name: Faker::Name.name, privilege_list: (['manage_tickets']), modules_scope: ({ 'tickets_scope' => '0' }))
    user = add_agent(@account, name: Faker::Name.name, active: 1, role_ids: ([role.id]))
    create_ticket_board(user_id: user.id)
    @request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(user.single_access_token, 'X')
    get(:index, params: controller_params({})[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    all_db_board_names = get_db_ticket_board_names(user)
    all_response_board_names = result[:boards].map { |board| board[:name] }
    expect((all_response_board_names - all_db_board_names)).to(be_empty)
stop()
  end
  it 'show board with invalid board id' do
start()
    get(:show, params: controller_params(id: 999999)[:params])
    assert_response(404)
stop()
  end
  it 'show board without board visibility' do
start()
    primary_workspace = Workspace.primary_workspace
    test_role = create_role(name: Faker::Name.name, privilege_list: (['manage_tickets']), modules_scope: ({ 'tickets_scope' => '0' }))
    ws_info = {
      workspace_info: [
        { workspace_id: primary_workspace.display_id, observer_of: [], member_of: [], roles: [{ role_id: test_role.id, role_type: 2  }] },
        { workspace_id: Workspace::GLOBAL_WORKSPACE_DISPLAY_ID, observer_of: [], member_of: [], roles: [{ role_id: test_role.id, role_type: 2  }] }
      ]
    }
    agent = add_test_esm_agent(@account, ws_info)
    log_in(agent)
    board = create_ticket_board
    @request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(agent.single_access_token, 'X')
    get(:show, params: controller_params({id: board.id, workspace_id: Workspace::PRIMARY_WORKSPACE_DISPLAY_ID})[:params])
    assert_response(404)
stop()
  end
  it 'show board with board visibility' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    board = create_ticket_board.reload
    get(:show, params: controller_params(id: board.id)[:params])
    assert_response(200)
    match_json(ticket_board_pattern(board: board, meta: true))
stop()
  end
  it 'show board for default board' do
start()
    id = 'my_board'
    destroy_default_board(id)
    expected_custom_config = default_board_initial_column_config
    get(:show, params: controller_params(id: id)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    result = result[:board]
    expect(result[:id]).to(eq(id))
    expect(result[:name]).to(eq('My Board'))
    expect(result[:default]).to(eq(true))
    expect(result[:query_hash]).to(eq(Board::TicketBoardsTestHelper::DEFAULT_BOARD_QUERY_HASH[id]))
    expect(result[:order_by]).to(eq('created_at'))
    expect(result[:order_type]).to(eq('desc'))
    expect(result[:wip_limit]).to(eq(expected_custom_config[:wip_limit]))
    expect(result[:column_order]).to(eq(expected_custom_config[:column_order]))
    expect(result[:custom_sort]).to(eq(expected_custom_config[:custom_sort]))
stop()
  end
  it 'show board with column order set' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    column_order = @account.ticket_statuses.select(:status_id).reverse.map { |s| s.status_id }
    board = create_ticket_board(column_order: column_order).reload
    get(:show, params: controller_params(id: board.id)[:params])
    assert_response(200)
    match_json(ticket_board_pattern(board: board, meta: true))
stop()
  end
  it 'create board without params' do
start()
    post(:create, params: construct_params({})[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:name, :missing_field), bad_request_error_pattern(:visibility, :missing_field)])
stop()
  end
  it 'create board with any random params' do
start()
    params = { test1: 'sample1', test2: 'sample2' }
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:test1, :invalid_field, message: 'Unexpected/invalid field in request'), bad_request_error_pattern(:test2, :invalid_field, message: 'Unexpected/invalid field in request')])
stop()
  end
  it 'create board with unsupported ticket fields' do
start()
    params = { subject: 'sample ticket', display_id: 1 }
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:subject, :invalid_field, message: 'Unexpected/invalid field in request'), bad_request_error_pattern(:display_id, :invalid_field, message: 'Unexpected/invalid field in request')])
stop()
  end
  it 'create board with invalid data type' do
start()
    params = { name: 12345, query_hash: "condition: responder_id, operator: is_in, type: default, value: '1,2,3'", visibility: ([1, 2, 3]), group_id: -2, wip_limit: 3, column_order: 'Desc' }
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:name, :datatype_mismatch, expected_data_type: (String), given_data_type: (Integer), prepend_msg: :input_received), bad_request_error_pattern(:query_hash, :datatype_mismatch, expected_data_type: (Array), given_data_type: (String), prepend_msg: :input_received), bad_request_error_pattern(:visibility, :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: (Array), prepend_msg: :input_received), bad_request_error_pattern(:group_id, :datatype_mismatch, expected_data_type: 'Positive Integer', code: :invalid_value), bad_request_error_pattern(:wip_limit, :datatype_mismatch, expected_data_type: (Array), given_data_type: (Integer), prepend_msg: :input_received), bad_request_error_pattern(:column_order, :datatype_mismatch, expected_data_type: (Array), given_data_type: (String), prepend_msg: :input_received)])
stop()
  end
  it 'create board without query hash condition' do
start()
    params = get_ticket_board_params
    (params[:query_hash] << { operator: 'is_in', type: 'default', value: (%w[1 2]) })
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern("query_hash[#{3}]", nil, append_msg: 'condition: This field cannot be empty', code: :invalid_value)])
stop()
  end
  it 'create board without query hash operator' do
start()
    params = get_ticket_board_params
    (params[:query_hash] << { condition: 'responder_id', type: 'default', value: (%w[1 2]) })
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern("query_hash[#{3}]", nil, append_msg: 'operator: This field cannot be empty', code: :invalid_value)])
stop()
  end
  it 'create board without query hash value' do
start()
    params = get_ticket_board_params
    (params[:query_hash] << { condition: 'responder_id', operator: 'is_in', type: 'default' })
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern("query_hash[#{3}]", nil, append_msg: 'value: This field cannot be empty', code: :invalid_value)])
stop()
  end
  it 'create board with invalid query hash condition' do
start()
    params = get_ticket_board_params
    (params[:query_hash] << { condition: 'subject', operator: 'is_in', type: 'default', value: (%w[1 2]) })
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern("query_hash[#{3}]", nil, append_msg: 'condition: is invalid', code: :invalid_value)])
stop()
  end
  it 'create board with invalid query hash operator' do
start()
    params = get_ticket_board_params
    (params[:query_hash] << { condition: 'responder_id', operator: 'equal_to', type: 'default', value: (%w[1 2]) })
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern("query_hash[#{3}]", nil, append_msg: ("operator: It should be one of these values: '#{Ticket::TicketFilterConstants.all_operators.join(",")}'"), code: :invalid_value)])
stop()
  end
  it 'create board with invalid query hash type' do
start()
    params = get_ticket_board_params
    (params[:query_hash] << { condition: 'responder_id', operator: 'is_in', type: 'default & custom', value: (%w[1 2]) })
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern("query_hash[#{3}]", nil, append_msg: ("type: It should be one of these values: '#{Ticket::TicketFilterConstants.query_type_options.join(",")}'"), code: :invalid_value)])
stop()
  end
  it 'create board with visibility only me but passing group id also' do
start()
    params = get_ticket_board_params
    params[:group_id] = @account.groups.last.id
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:group_id, nil, append_msg: 'must be blank', code: :invalid_value)])
stop()
  end
  it 'create board with visibility group agents and invalid group id' do
start()
    params = get_ticket_board_params
    params[:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
    params[:group_id] = 99999999
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:group_id, nil, append_msg: I18n.t('cmdb.contract.invalid_group_id'), code: :invalid_value)])
stop()
  end
  it 'create board with visibility group agents without group id' do
start()
    params = get_ticket_board_params
    params[:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:group_id, :missing_field)])
stop()
  end
  it 'create board with invalid visibility' do
start()
    visibility_list = Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.join(',')
    params = get_ticket_board_params
    params[:visibility] = (Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys.last + 1)
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:visibility, :not_included, list: visibility_list, code: :invalid_value)])
stop()
  end
  it 'create board with invalid column order' do
start()
    params = get_ticket_board_params
    params[:column_order] = [-1, 0]
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern_with_nested_field(:column_order, '[0]', nil, append_msg: 'It should be of type Positive Integer', code: :invalid_value)])
stop()
  end
  it 'create board with invalid wip limit' do
start()
    params = get_ticket_board_params
    params[:wip_limit] = [{ column_id: -2, limit: 100 }, { column_id: 3, limit: 0 }]
    post(:create, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:wip_limit, nil, append_msg: 'invalid_wip_limit', code: :invalid_wip_limit)])
stop()
  end
  it 'board create errors' do
start()
    begin
      (allow_any_instance_of(Board::TicketBoard).to receive(:save).and_return(false)
       allow_any_instance_of(Board::TicketBoard).to receive(:errors).and_return(id: 'Cannot be negative')
       params = get_ticket_board_params
       post(:create, params: construct_params(params)[:params])
       assert_response(400))
    ensure

stop()
    end
stop()
  end
  it 'create ticket board without manage tickets privilege' do
start()
    params = get_ticket_board_params
    @request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(get_user_without_manage_tickets_privilege.single_access_token, 'X')
    post(:create, params: construct_params(params)[:params])
    assert_response(403)
stop()
  end
  it 'create ticket board' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    stub_public_api
    create_dropdown_field
    params = get_ticket_board_params
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last))
stop()
  end
  it 'create board with extra query hash fields' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    params = get_ticket_board_params
    (params[:query_hash] << { condition: 'ticket_type', operator: 'is_in', type: 'default', value: (['Incident']), label: 'default', name: 'default' })
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last, meta: true))
stop()
  end
  it 'create ticket board esm' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    ws = Workspace.where.not(display_id: (Workspace::GLOBAL_WORKSPACE_DISPLAY_ID)).first.make_current
    workspace_id = ws.display_id
    create_dropdown_field(workspace_id: workspace_id)
    params = get_ticket_board_params
    params.merge!(workspace_id: workspace_id)
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last, meta: true))
stop()
  end
  it 'create ticket board with all agents visibility' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    params = get_ticket_board_params
    params[:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last, meta: true))
stop()
  end
  it 'create ticket board with group agents visibility' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    params = get_ticket_board_params
    params[:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents]
    params[:group_id] = @account.groups.sample.id
    agent_role = @account.roles.find_by(name: (SpecConstants::AGENT))
    add_agent(@account, group_id: params[:group_id], role_ids: ([agent_role.id]), privileges: agent_role.privileges)
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last, meta: true))
stop()
  end
  it 'create board with parent id' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    board = create_ticket_board
    column_id = @account.ticket_statuses.sample.status_id
    tickets = @account.tickets.select(:display_id).limit(10)
    board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
    params = get_ticket_board_params
    params[:parent_id] = board.id
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    result = parse_response(response.body)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last, meta: true))
    expect(result['board']['custom_sort']).to(eq(true))
stop()
  end
  it 'create board with parent id as a default board' do
start()
    allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
    @agent.make_current
    board = (User.current.agent.default_boards.find_by(name: 'my_board') or seed_default_ticket_board('my_board'))
    unless board.columns.any? then
      column_id = @account.ticket_statuses.sample.status_id
      tickets = @account.tickets.select(:display_id).limit(10)
      board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
stop()
    end
    params = get_ticket_board_params
    params[:parent_id] = board.name
    post(:create, params: construct_params(params)[:params])
    assert_response(201)
    result = parse_response(response.body)
    match_json(ticket_board_pattern(board: Account.current.ticket_boards.last, meta: true))
    expect(result['board']['custom_sort']).to(eq(true))
stop()
  end
  it 'create ticket board without manage users privilege' do
start()
    begin
      (params = get_ticket_board_params
       params[:visibility] = Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents]
       allow_any_instance_of(Board::BoardsController).to receive(:privilege?).with(:manage_users).and_return(false)
       post(:create, params: construct_params(params)[:params])
       expect(Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:only_me]).to(eq(JSON.parse(response.body)['board']['visibility'])))
    ensure

stop()
    end
stop()
  end
  it 'update ticket board with invalid board id' do
start()
    put(:update, params: construct_params(id: 99999999)[:params])
    assert_response(404)
stop()
  end
  it 'board update errors' do
start()
    begin
      (allow_any_instance_of(Board::TicketBoard).to receive(:save).and_return(false)
       allow_any_instance_of(Board::TicketBoard).to receive(:errors).and_return(id: 'Cannot be negative')
       board = get_board('Helpdesk::Ticket')
       params = { id: board.id, name: ("#{board.name} - #{Time.zone.now} Updated") }
       put(:update, params: construct_params(params)[:params])
       assert_response(400))
    ensure

stop()
    end
stop()
  end
  it 'default board update with restricted params' do
start()
    params = { id: 'my_board', name: 'new_tickets', query_hash: get_ticket_board_params[:query_hash], visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents], group_id: @account.groups.sample.id }
    put(:update, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:name, :invalid_field, message: 'Unexpected/invalid field in request'), bad_request_error_pattern(:query_hash, :invalid_field, message: 'Unexpected/invalid field in request'), bad_request_error_pattern(:visibility, :invalid_field, message: 'Unexpected/invalid field in request'), bad_request_error_pattern(:group_id, :invalid_field, message: 'Unexpected/invalid field in request')])
stop()
  end
  it 'update ticket board without manage tickets privilege' do
start()
    board = get_board('Helpdesk::Ticket')
    @request.env['HTTP_AUTHORIZATION'] = ActionController::HttpAuthentication::Basic.encode_credentials(get_user_without_manage_tickets_privilege.single_access_token, 'X')
    params = { id: board.id, name: ("#{board.name} - #{Time.zone.now} Updated") }
    put(:update, params: construct_params(params)[:params])
    assert_response(403)
stop()
  end
  it 'update ticket board name that created by someother user and without manage users privilege' do
start()
    board = get_board('Helpdesk::Ticket')
    user = add_test_agent(@account)
    board.accessible.user_id = user.id
    board.accessible.sneaky_save
    allow_any_instance_of(User).to receive(:privilege?).with(:manage_tickets, nil, {options: {account_level_access: false, workspace_id: nil}}).and_return(false)
    params = { id: board.id, name: ("#{board.name} - #{Time.zone.now} Updated") }
    put(:update, params: construct_params(params)[:params])
    assert_response(403)
stop()
  end
  it 'update ticket board name that created by someother user and with manage users privilege' do
start()
    board = create_ticket_board(visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents])
    user = add_test_agent(@account)
    board.accessible.user_id = user.id
    board.accessible.sneaky_save
    params = { id: board.id, name: ("#{board.name} - #{Time.zone.now} Updated") }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:name]).to(eq(params[:name]))
stop()
  end
  it 'update ticket board name' do
start()
    board = get_board('Helpdesk::Ticket')
    params = { id: board.id, name: ("#{board.name} - #{Time.zone.now} Updated") }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:name]).to(eq(params[:name]))
stop()
  end
  it 'update ticket board to default sort' do
start()
    board = create_ticket_board
    column_id = @account.ticket_statuses.sample.status_id
    tickets = @account.tickets.select(:display_id).limit(10)
    board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
    params = { id: board.id, custom_sort: false }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:custom_sort]).to(eq(params[:custom_sort]))
stop()
  end
  it 'update default ticket board to default sort' do
start()
    @agent.make_current
    board = (User.current.agent.default_boards.find_by(name: 'my_board') or seed_default_ticket_board('my_board'))
    unless board.columns.any? then
      column_id = @account.ticket_statuses.sample.status_id
      tickets = @account.tickets.select(:display_id).limit(10)
      board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
stop()
    end
    params = { id: board.name, custom_sort: false }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:custom_sort]).to(eq(params[:custom_sort]))
stop()
  end
  it 'update ticket board visibility from only me to group agents' do
start()
    board = create_ticket_board
    params = { id: board.id, visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents], group_id: @account.groups_from_cache.sample.id }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:id]).to(eq(params[:id]))
    expect(result[:board][:visibility]).to(eq(params[:visibility]))
    expect(result[:board][:group_id]).to(eq(params[:group_id]))
stop()
  end
  it 'update ticket board query hash condition' do
start()
    board = create_ticket_board
    old_query_hash = get_presentable_query_hash(board)[:query_hash]
    new_query_hash = old_query_hash.concat([{ condition: 'priority', operator: 'is_in', type: 'default', value: (%w[2 3 4]) }, { condition: 'urgency', operator: 'is_in', type: 'default', value: (%w[1 2 3]) }])
    params = { id: board.id, query_hash: new_query_hash }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:id]).to(eq(params[:id]))
    expect((new_query_hash.map { |f| f[:condition] } - result[:board][:query_hash].map { |f| f[:condition] }.uniq)).to(be_empty)
stop()
  end
  it 'update default ticket board' do
start()
    params = { id: 'my_board', column_order: ([2, 4, 3]), wip_limit: ([{ column_id: 2, limit: 20 }, { column_id: 3, limit: 50 }]) }
    put(:update, params: construct_params(params)[:params])
    assert_response(200)
    result = parse_response(response.body).deep_symbolize_keys
    expect(result[:board][:id]).to(eq(params[:id]))
    expect(result[:board][:column_order]).to(eq(params[:column_order]))
    expect(result[:board][:wip_limit]).to(eq(params.deep_symbolize_keys[:wip_limit]))
stop()
  end
  it 'delete ticket board with invalid board id' do
start()
    delete(:destroy, params: construct_params(id: 99999999)[:params])
    assert_response(404)
stop()
  end
  it 'delete ticket board that created by someother user and without manage users privilege' do
start()
    begin
      (@agent.make_current
       user = add_test_agent(@account)
       board = create_ticket_board(user_id: user.id)
       allow_any_instance_of(Board::BoardsController).to receive(:privilege?).with(:manage_users).and_return(false)
       delete(:destroy, params: construct_params(id: board.id)[:params])
       assert_response(404))
    ensure

stop()
    end
stop()
  end
  it 'delete default ticket board' do
start()
    delete(:destroy, params: construct_params(id: 'my_board')[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:base, :undestroyable, message: 'Undestroyable')])
stop()
  end
  it 'board delete errors' do
start()
    begin
      (allow_any_instance_of(Board::TicketBoard).to receive(:destroy).and_return(false)
       allow_any_instance_of(Board::TicketBoard).to receive(:errors).and_return(id: 'Cannot be negative')
       board = create_ticket_board
       delete(:destroy, params: construct_params(id: board.id)[:params])
       assert_response(500))
    ensure

stop()
    end
stop()
  end
  it 'delete ticket board that created by someother user and with manage users privilege' do
start()
    @agent.make_current
    user = add_test_agent(@account)
    board = create_ticket_board(visibility: Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:all_agents], user_id: user.id)
    delete(:destroy, params: construct_params(id: board.id)[:params])
    assert_response(204)
    expect(Wf::Filter.find_by(id: board.id)).to(be_nil)
stop()
  end
  it 'delete ticket board' do
start()
    board = create_ticket_board
    delete(:destroy, params: construct_params(id: board.id)[:params])
    assert_response(204)
    expect(Wf::Filter.find_by(id: board.id)).to(be_nil)
stop()
  end
  it 'configure column without params' do
start()
    board = get_board('Helpdesk::Ticket')
    post(:configure_column, params: construct_params(id: board.id)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:column_id, :missing_field), bad_request_error_pattern(:card_order, :missing_field)])
stop()
  end
  it 'configure column with random params' do
start()
    board = get_board('Helpdesk::Ticket')
    post(:configure_column, params: construct_params(id: board.id, test1: 'sample_test', test2: 3)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:test1, :invalid_field, message: 'Unexpected/invalid field in request'), bad_request_error_pattern(:test2, :invalid_field, message: 'Unexpected/invalid field in request')])
stop()
  end
  it 'configure column with invalid data type' do
start()
    board = get_board('Helpdesk::Ticket')
    post(:configure_column, params: construct_params(id: board.id, column_id: 'sample_test', last_loaded_entity: (['test']), card_order: 3)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:column_id, :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: (String), prepend_msg: :input_received), bad_request_error_pattern(:last_loaded_entity, :datatype_mismatch, expected_data_type: 'Positive Integer', given_data_type: (Array), prepend_msg: :input_received), bad_request_error_pattern(:card_order, :datatype_mismatch, expected_data_type: (Array), given_data_type: (Integer), prepend_msg: :input_received)])
stop()
  end
  it 'configure column with card order size greater than max limit' do
start()
    board = get_board('Helpdesk::Ticket')
    params = get_column_config_params(board)
    params[:card_order] = (1..(Board::Constants::CARD_ORDER_MAX_LIMIT + 1)).map { |n| n }
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(400)
    match_json([bad_request_error_pattern(:card_order, nil, append_msg: ("It should only contain elements that have maximum of #{Board::Constants::CARD_ORDER_MAX_LIMIT} IDs"), code: :invalid_value)])
stop()
  end
  it 'configure column errors' do
start()
    board = create_ticket_board
    params, column = get_column_config_params(board), board.columns.new
    allow(column).to receive(:errors).and_return(ActiveModel::Errors.new(column).tap { |e| e.add(:name, 'Cannot be negative') })
    allow_any_instance_of(Board::ColumnUtil).to receive(:set_card_order).and_return(column)
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(400)
stop()
  end
  it 'configure column on existing card order errors' do
start()
    board = create_ticket_board
    column_id = @account.ticket_statuses.sample.status_id
    tickets = @account.tickets.select(:display_id).limit(10)
    last_loaded_entity = tickets.last.display_id
    column = board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
    params = get_column_config_params(board, column_id: column_id, last_loaded_entity: last_loaded_entity)
    allow(column).to receive(:errors).and_return(ActiveModel::Errors.new(column).tap { |e| e.add(:name, 'Cannot be negative') })
    allow_any_instance_of(Board::ColumnUtil).to receive(:set_card_order).and_return(column)
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(400)
stop()
  end
  it 'configure column' do
start()
    board = create_ticket_board
    params = get_column_config_params(board)
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(200)
stop()
  end
  it 'configure column for default board' do
start()
    @agent.make_current
    board = (User.current.agent.default_boards.find_by(name: 'my_board') or seed_default_ticket_board('my_board'))
    params = get_column_config_params(board)
    params[:id] = board.name
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(200)
stop()
  end
  it 'configure column on existing card order' do
start()
    board = create_ticket_board
    column_id = @account.ticket_statuses.sample.status_id
    tickets = @account.tickets.select(:display_id).limit(10)
    last_loaded_entity = tickets.last.display_id
    board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
    params = get_column_config_params(board, column_id: column_id, last_loaded_entity: last_loaded_entity)
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(200)
stop()
  end
  it 'configure column on existing card order without last loaded entity' do
start()
    board = create_ticket_board
    column_id = @account.ticket_statuses.sample.status_id
    tickets = @account.tickets.select(:display_id).limit(10)
    board.columns.create(column_id: column_id, card_order: (tickets.map { |t| t.display_id }))
    params = get_column_config_params(board, column_id: column_id)
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(200)
stop()
  end
  it 'configure column on existing card order with new last loaded entity' do
start()
    board = create_ticket_board
    column_id = @account.ticket_statuses.sample.status_id
    tickets = @account.tickets.select(:display_id).limit(11)
    last_loaded_entity = tickets.last.display_id
    board.columns.create(column_id: column_id, card_order: (tickets.first((tickets.size - 1)).map { |t| t.display_id }))
    params = get_column_config_params(board, column_id: column_id, last_loaded_entity: last_loaded_entity)
    post(:configure_column, params: construct_params(params)[:params])
    assert_response(200)
stop()
  end
  it 'expect custom field filter to be saved and retrieved' do
start()
    begin
      allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
      Sidekiq::Testing.inline! do
start()
        Account.current.enable_ticket_filters_v2!
        @ws = create_workspaces
        @ws.make_current
        select_list = 5.times.map { Faker::Lorem.word }
        selected_val = select_list[0]
        create_custom_field_dropdown('fssampletest', select_list, workspace_id: @ws[:display_id])
        board = create_ticket_board
        board[:workspace_id] = @ws[:display_id]
        board.save
        params = {id: board.id, query_hash: [{ value:[selected_val], condition: 'fssampletest', type: 'custom_field', operator: 'is_in' }]}
        put(:update, params: construct_params(params)[:params])
        res = JSON.parse(response.body)
        expect(res['board']['query_hash'][0]['value']).to eql([selected_val])
stop()
      end
    ensure
      @ws.destroy
stop()
    end
stop()
  end

  it 'expect custom field filter to be saved and retrieved using show method' do
start()
    begin
      allow(Workspace).to receive(:multi_workspace_mode?).and_return(true)
      Sidekiq::Testing.inline! do
start()
        Account.current.enable_ticket_filters_v2!
        @ws = create_workspaces
        @ws.make_current
        select_list = 5.times.map { Faker::Lorem.word }
        selected_val = select_list[0]
        create_custom_field_dropdown('fssampletest', select_list, workspace_id: @ws[:display_id])
        board = create_ticket_board
        board[:workspace_id] = @ws[:display_id]
        board.save
        params = {id: board.id, query_hash: [{ value:[selected_val], condition: 'fssampletest', type: 'custom_field', operator: 'is_in' }]}
        put(:update, params: construct_params(params)[:params])

        get(:show, params: construct_params(id: board.id)[:params])
        res = JSON.parse(response.body)
        expect(res['board']['query_hash'][0]['value']).to eql([selected_val])
stop()
      end
    ensure
      @ws.destroy
stop()
    end
stop()
  end
stop()
end
