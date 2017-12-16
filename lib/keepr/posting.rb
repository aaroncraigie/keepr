class Keepr::Posting < ActiveRecord::Base
  self.table_name = 'keepr_postings'

  validates_presence_of :keepr_account_id, :amount
  validate :cost_center_validation

  belongs_to :keepr_account, class_name: 'Keepr::Account'
  belongs_to :keepr_journal, class_name: 'Keepr::Journal'
  belongs_to :keepr_cost_center, class_name: 'Keepr::CostCenter'
  belongs_to :accountable, polymorphic: true

  SIDE_DEBIT  = 'debit'
  SIDE_CREDIT = 'credit'

  scope :debits,  -> { where('amount >= 0') }
  scope :credits, -> { where('amount < 0') }

  def side
    @side || begin
      (raw_amount < 0 ? SIDE_CREDIT : SIDE_DEBIT) if raw_amount
    end
  end

  def side=(value)
    @side = value

    if credit?
      self.raw_amount = -amount if amount
    elsif debit?
      self.raw_amount =  amount if amount
    else
      raise ArgumentError
    end
  end

  def debit?
    side == SIDE_DEBIT
  end

  def credit?
    side == SIDE_CREDIT
  end

  def raw_amount
    read_attribute(:amount)
  end

  def raw_amount=(value)
    write_attribute(:amount, value)
  end

  def amount
    raw_amount.try(:abs)
  end

  def amount=(value)
    raise ArgumentError.new('Negative amount not allowed!') if value.to_f < 0
    @side ||= SIDE_DEBIT

    if credit?
      self.raw_amount = -value
    else
      self.raw_amount = value
    end
  end

private
  def cost_center_validation
    if keepr_cost_center
      unless keepr_account.profit_and_loss?
        # allowed for expense or revenue accounts only
        errors.add :keepr_cost_center_id, :allowed_for_expense_or_revenue_only
      end
    end
  end
end
