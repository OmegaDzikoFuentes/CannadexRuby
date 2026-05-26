class ConvertTextJsonToJsonb < ActiveRecord::Migration[8.0]
  def up
    # activities.data
    add_column :activities, :data_jsonb, :jsonb, default: {}
    Activity.find_each do |a|
      next unless a.data.present?
      parsed = JSON.parse(a.data) rescue {}
      a.update_column(:data_jsonb, parsed)
    end
    remove_column :activities, :data
    rename_column :activities, :data_jsonb, :data
    change_column_default :activities, :data, from: {}, to: {}
    add_index :activities, :data, using: :gin

    # battles.battle_results
    add_column :battles, :battle_results_jsonb, :jsonb, default: {}
    Battle.find_each do |b|
      next unless b.battle_results.present?
      parsed = JSON.parse(b.battle_results) rescue {}
      b.update_column(:battle_results_jsonb, parsed)
    end
    remove_column :battles, :battle_results
    rename_column :battles, :battle_results_jsonb, :battle_results
    change_column_default :battles, :battle_results, from: {}, to: {}

    # battle_rounds.round_results
    add_column :battle_rounds, :round_results_jsonb, :jsonb, default: {}
    BattleRound.find_each do |r|
      next unless r.round_results.present?
      parsed = JSON.parse(r.round_results) rescue {}
      r.update_column(:round_results_jsonb, parsed)
    end
    remove_column :battle_rounds, :round_results
    rename_column :battle_rounds, :round_results_jsonb, :round_results
    change_column_default :battle_rounds, :round_results, from: {}, to: {}
  end

  def down
    # activities.data
    add_column :activities, :data_text, :text
    Activity.find_each { |a| a.update_column(:data_text, a.data.to_json) }
    remove_index :activities, :data
    remove_column :activities, :data
    rename_column :activities, :data_text, :data

    # battles.battle_results
    add_column :battles, :battle_results_text, :text
    Battle.find_each { |b| b.update_column(:battle_results_text, b.battle_results.to_json) }
    remove_column :battles, :battle_results
    rename_column :battles, :battle_results_text, :battle_results

    # battle_rounds.round_results
    add_column :battle_rounds, :round_results_text, :text
    BattleRound.find_each { |r| r.update_column(:round_results_text, r.round_results.to_json) }
    remove_column :battle_rounds, :round_results
    rename_column :battle_rounds, :round_results_text, :round_results
  end
end