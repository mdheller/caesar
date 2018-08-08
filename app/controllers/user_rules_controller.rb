class UserRulesController < ApplicationController
  def index
    authorize workflow

    rules = UserRule.where(workflow_id: params[:workflow_id])
    respond_to do |format|
      format.html { redirect_to workflow }
      format.json { render json: rules }
    end
  end

  def show
    authorize workflow
    @rule = workflow.user_rules.find(params[:id]) or not_found
    respond_with @rule
  end

  def new
    authorize workflow
    @rule = UserRule.new(workflow: workflow)
  end

  def edit
    authorize workflow
    @rule = UserRule.find(workflow: workflow) or not_found
  end

  def create
    authorize workflow

    @rule = UserRule.new(rule_params)
    @rule.save

    respond_to do |format|
      format.html{ redirect_to workflow }
      format.json{ render json: @rule}
    end
  end

  def update
    authorize workflow
    @rule = workflow.user_rules.find(params[:id]) or not_found

    if @rule.update(rule_params)
      respond_to do |format|
        format.html { redirect_to workflow, success: 'Rule updated' }
        format.json { render json: @rule }
      end
    else
      respond_with @rule
    end
  end

  def destroy
    authorize workflow
    rule = workflow.user_rules.find(params[:id])

    rule.destroy
    respond_with rule, location: [workflow]
  end

  private

  def workflow
    @workflow ||= policy_scope(Workflow).find(params[:workflow_id])
  end

  def rule_params
    p = params.require(:user_rule).permit(:condition, :id)
    p.merge(condition: JSON.parse(p["condition"]), workflow_id: workflow.id)
  end
end