import "dart:html";
import "dart:math";

import "package:CommonLib/Utility.dart";

import "dice.dart";
import "pool.dart";
import "criteria.dart";
import "utility.dart";
import 'workertest.dart';

Random rand = new Random();

DicePoolUI poolUI;
CriterionSelectorUI selector;
ResultsBox results;

void main() {

    poolUI = new DicePoolUI();
    selector = new CriterionSelectorUI();

    querySelector("#pool")..append(poolUI.element);
    querySelector("#criteria")..append(selector.element);

    querySelector("#chanceButton").onClick.listen(roll);

    results = new ResultsBox();

    /*DateTime before = new DateTime.now();
    querySelector("#table")..append(rollTable());
    DateTime after = new DateTime.now();
    int diff = after.millisecondsSinceEpoch - before.millisecondsSinceEpoch;
    print(diff);*/
    
    /*DicePool p = new DicePool()
        ..add(Dice.BOOST, 1)
        //..add(Dice.ABILITY, 2)
        ..add(Dice.PROFICIENCY, 3)
        ..add(Dice.DIFFICULTY, 1)
        //..add(Dice.CHALLENGE,1)
        //..add(Dice.SETBACK, 3)
    ;

    double b = p.chanceOfResults(C.compare(Dice.SUCCESS, Comparison.GREATER_THAN_OR_EQUAL, 5));
    print(b);*/

    //testWorkers();
}

DicePool buildPool() {
    DicePool pool = new DicePool();

    for (DiceType type in Dice.ALL_DICE) {
        pool.add(type, poolUI.getDice(type));
    }
    for (SymbolType type in Dice.ALL_SYMBOLS) {
        pool.addSymbol(type, poolUI.getSymbol(type));
    }

    return pool;
}

void roll([Event e]) {
    DicePool pool = buildPool();

    //DiceResult result = pool.roll(rand);

    //print(result.symbols);

    double chance = pool.chanceOfResults(selector.buildCriterion());
    results.update(chance);
}

Map<SymbolType, double> statsFromResults(List<DiceResult> results) {
    DiceResult aggregate = new DiceResult();

    for (DiceResult result in results) {
        for (Face face in result.faces) {
            aggregate.addFace(face);
        }
    }

    aggregate.tidy();

    Map<SymbolType, double> stats = <SymbolType, double>{};
    for (SymbolType symbol in aggregate.symbols.keys) {
        stats[symbol] = aggregate.symbols[symbol] / results.length;
    }

    return stats;
}

Map<SymbolType, double> statsFromPool(DicePool pool) {
    return pool.getStats();
}

double successFromResults(List<DiceResult> results) {
    int count = 0;

    for (DiceResult result in results) {
        if (result.symbols.containsKey(Dice.SUCCESS)) {
            count++;
        }
    }

    return count / results.length;
}

double successFromPool(DicePool pool) {
    return pool.chanceOfAtLeast(1, Dice.SUCCESS);
}

double critFromPool(DicePool pool) {
    return pool.chanceOfAtLeast(1, Dice.TRIUMPH);
}

List<DicePool> skillSequence(DiceType statDice, DiceType skillDice, int min, int max) {
    List<DicePool> pools = <DicePool>[];

    for (int stat=min; stat<=max; stat++) {
        for (int skill = 0; skill <= stat; skill++ ) {
            DicePool pool = new DicePool();

            pool.add(statDice, stat - skill);
            pool.add(skillDice, skill);

            pools.add(pool);
        }
    }

    return pools;
}

Element rollTable() {
    TableElement table = new TableElement()..className="diceTable";

    List<DicePool> skills = skillSequence(Dice.ABILITY, Dice.PROFICIENCY, 1, 5);
    List<DicePool> difficulties = skillSequence(Dice.DIFFICULTY, Dice.CHALLENGE, 0, 5);

    List<DicePool> xPools = difficulties;
    List<DicePool> yPools = skills;

    //List<DicePoolComparisonCriterion> criteria = <DicePoolComparisonCriterion>[new DicePoolComparisonCriterion(Dice.SUCCESS, Comparison.GREATER_THAN_OR_EQUAL, 1)];
    Criterion criteria = C.compare(Dice.SUCCESS, Comparison.GREATER_THAN_OR_EQUAL, 1);

    for (int y = 0; y <= yPools.length; y++) {
        TableRowElement row = new TableRowElement();
        DicePool rowPool = y==0 ? null : yPools[y-1];

        for (int x = 0; x <= xPools.length; x++) {
            Element cell = (x == 0 || y == 0) ? new Element.th() : new TableCellElement();
            DicePool columnPool = x == 0 ? null : xPools[x-1];

            if (x == 0 && y > 0) {
                // row head
                cell.className = "rowHead";
                DicePool pool = rowPool;
                cell.append(pool.createDisplayElement());
            } else if (y == 0 && x > 0) {
                // column head
                cell.className = "columnHead";
                DicePool pool = columnPool;
                cell.append(pool.createDisplayElement());
            } else if (x > 0 && y > 0) {
                // body
                DicePool pool = new DicePool.merged(columnPool, rowPool);

                cell.innerHtml = "${(pool.chanceOfResults(criteria) * 100).toStringAsFixed(1)}%";
                //cell.innerHtml = "${(pool.chanceOfAtLeast(1, Dice.SUCCESS) * 100).toStringAsFixed(1)}%";
            }

            // section division lines
            if (x > 0 && x <= xPools.length -1) {
                if (xPools[x-1].size != xPools[x].size) {
                    cell.className += " columnBreak";
                }
            }
            if (y > 0 && y <= yPools.length -1) {
                if (yPools[y-1].size != yPools[y].size) {
                    cell.className += " rowBreak";
                }
            }

            row.append(cell);
        }

        table.append(row);
    }

    return table;
}

class ResultsBox {
    Element _element = querySelector("#resultBox");
    Element _percent = querySelector("#resultPercentage");
    Element _chance = querySelector("#resultChance");
    Element _numerator = querySelector("#resultNumerator");
    Element _deonominator = querySelector("#resultDenominator");
    Element _approx = querySelector("#resultApprox");
    
    ResultBox() {
        
    }
    
    void update(double result) {
        if (result == null) { return; }
        _element.style.display = "block";

        if (result == 1 || result == 0) {

            _chance.text = "$result.0";
        } else {
            _chance.text = "$result";
        }

        if (result * 100 == (result*100).round()) {
            _percent.text = "${(result * 100).toStringAsFixed(0)}%";
        } else {
            _percent.text = "${(result * 100).toStringAsFixed(1)}%";
        }

        Tuple<int,int> fraction = approximateFraction(result);

        double estimate = fraction.first / fraction.second;
        if ((result - estimate).abs() != 0.0) {
            _approx.text = "Approximately";
        } else {
            _approx.text = "";
        }


        _numerator.text = fraction.first.toString();
        _deonominator.text = fraction.second.toString();
    }
}