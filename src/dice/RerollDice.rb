# -*- coding: utf-8 -*-

require "utils/normalize"

module RerollDice
  include Normalize

  # @param [String] string
  # @return [String | nil]
  def eval_reroll_dice(string)
    output = dice_command_xRn(string, "")
    if output != '1' && !output.nil? && !output.empty?
      return output
    end

    debug('RerollDice.rollDice string', string)
    string = string.strip

    m = /^S?(\d+R\d+(?:\+\d+R\d+)*)(?:\[(\d+)\])?(?:([<>=]+)(\d+))?(?:@(\d+))?$/.match(string)
    unless m
      return nil
    end

    @secret = string[0] == 'S'

    string, braceThreshold, operator, conditionValue, atmarkThreshold = m.captures

    signOfInequality, diff = getCondition(operator, conditionValue)
    operator_sym = normalize_operator(signOfInequality)
    rerollNumber = getRerollNumber(braceThreshold, atmarkThreshold, diff)
    debug('rerollNumber', rerollNumber)

    debug("diff", diff)

    diceQueue = []
    string.split("+").each do |xRn|
      x, n = xRn.split("R").map { |s| s.to_i }
      checkReRollRule(n, signOfInequality, diff)

      diceQueue.push([x, n, 0])
    end

    successCount = 0
    diceStrList = []
    dice_cnt_total = 0
    numberSpot1Total = 0
    loopCount = 0

    while !diceQueue.empty? && should_reroll?(loopCount)
      # xRn
      x, n, depth = diceQueue.shift
      loopCount += 1

      dice_list = @randomizer.roll_barabara(x, n)
      total = dice_list.sum
      numberSpot1 = dice_list.count(1)
      success = if diff.nil?
                  0
                else
                  dice_list.count { |val| val.send(operator_sym, diff) }
                end

      rerollCount = if rerollNumber.nil?
                      0
                    else
                      dice_list.count { |val| val >= rerollNumber }
                    end

      if @sortType & 2 != 0
        dice_list = dice_list.sort()
      end
      text = dice_list.join(",")

      successCount += success
      diceStrList.push(text)
      dice_cnt_total += x

      if depth.zero?
        numberSpot1Total += numberSpot1
      end

      if rerollCount > 0
        diceQueue.push([rerollCount, n, depth + 1])
      end
    end

    output = "#{diceStrList.join(' + ')} ＞ 成功数#{successCount}"
    string += "[#{rerollNumber}]#{signOfInequality}#{diff}"

    debug("string", string)
    output += getGrichText(numberSpot1Total, dice_cnt_total, successCount)

    output = "(#{string}) ＞ #{output}"

    if output.length > $SEND_STR_MAX # 長すぎたときの救済
      output = "(#{string}) ＞ ... ＞ 回転数#{round} ＞ 成功数#{successCount}"
    end

    return ": #{output}"
  rescue InvalidJudgeRule
    return ": #{string} ＞ 条件が間違っています。2R6>=5 あるいは 2R6[5] のように振り足し目標値を指定してください。"
  end

  def getCondition(operator, conditionValue)
    if operator && conditionValue
      operator = marshalSignOfInequality(operator)
      conditionValue = conditionValue.to_i
    elsif (m = /([<>=]+)(\d+)/.match(@defaultSuccessTarget))
      operator = marshalSignOfInequality(m[1])
      conditionValue = m[2].to_i
    end

    return operator, conditionValue
  end

  def getRerollNumber(braceThreshold, atmarkThreshold, conditionValue)
    if braceThreshold
      braceThreshold.to_i
    elsif atmarkThreshold
      atmarkThreshold.to_i
    elsif @rerollNumber != 0
      @rerollNumber
    elsif conditionValue
      conditionValue.to_i
    else
      raise InvalidJudgeRule
    end
  end

  def checkReRollRule(dice_max, signOfInequality, diff) # 振り足しロールの条件確認
    valid = true

    case signOfInequality
    when '<='
      valid = false if diff >= dice_max
    when '>='
      valid = false if diff <= 1
    when '<>'
      valid = false if (diff > dice_max) || (diff < 1)
    when '<'
      valid = false if diff > dice_max
    when '>'
      valid = false if diff < 1
    end

    unless valid
      raise InvalidJudgeRule
    end
  end
end

class InvalidJudgeRule < StandardError; end
