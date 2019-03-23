import "dart:html";
import "dart:math";

import "criteria.dart";
import "dice.dart";

//import "package:CommonLib/Utility.dart";

class DicePool {
    Map<DiceType, int> dice = <DiceType, int>{};
    Map<SymbolType, int> extraSymbols = <SymbolType, int>{};

    DicePool();

    factory DicePool.merged(DicePool first, DicePool second) {
        DicePool pool = new DicePool();

        for (DiceType d in first.dice.keys) {
            pool.add(d, first.dice[d]);
        }
        for (DiceType d in second.dice.keys) {
            pool.add(d, second.dice[d]);
        }

        return pool;
    }

    void add(DiceType type, [int count=1]) {
        if (count == 1) {
            _addOne(type);
        } else {
            for (int i = 0; i < count; i++) {
                _addOne(type);
            }
        }
    }

    void _addOne(DiceType type) {
        if (!dice.containsKey(type)) {
            dice[type] = 0;
        }
        dice[type] = dice[type] + 1;
    }

    void addSymbol(SymbolType type, [int count = 1]) {
        if (count <= 0) { return; }
        if (!extraSymbols.containsKey(type)) {
            extraSymbols[type] = 0;
        }
        extraSymbols[type] = extraSymbols[type] + count;
    }

    int get size {
        int count = 0;
        for (DiceType type in dice.keys) {
            count += dice[type];
        }
        return count;
    }

    void forEach(void action(DiceType t)) {
        for (DiceType type in dice.keys) {
            int count = dice[type];
            for (int i=0; i<count; i++) {
                action(type);
            }
        }
    }

    DiceResult roll(Random rand) {
        DiceResult result = new DiceResult();

        this.forEach((DiceType type) {
            result.addFace(type.roll(rand));
        });

        for(SymbolType s in extraSymbols.keys) {
            for (int i=0; i < extraSymbols[s]; i++) {
                result.addSymbol(s);
            }
        }

        result.tidy();
        return result;
    }

    List<DiceResult> getAllResults() {
        List<DiceType> flatdice = <DiceType>[];

        int total = 1;
        this.forEach((DiceType type) {
            flatdice.add(type);
            total *= type.sides;
        });
        List<DiceResult> results = new List<DiceResult>(total);
        int diceCount = flatdice.length;

        //print("sides: ${flatdice.map((DiceType d) => d.sides).toList()}");

        List<int> loop = new List<int>.filled(diceCount, 0);
        List<int> levelSize = new List<int>.generate(diceCount, (int level) {
            int size = 1;
            for (int i=level+1; i<diceCount; i++) {
                size *= flatdice[i].sides;
            }
            return size;
        });
        //print(levelSize);

        int id;
        var process;
        process = (int level) {
            DiceType d = flatdice[level];
            for (int i=0; i<d.sides; i++) {
                if (level >= diceCount-1) {
                    // final level of the iteration
                    id = 0;
                    for (int l=0; l<diceCount; l++) {
                        id += levelSize[l] * loop[l];
                    }

                    DiceResult result = new DiceResult();
                    for (int l=0; l<diceCount; l++) {
                        result.addFace(flatdice[l].faces[loop[l]]);
                    }
                    result.tidy();
                    results[id] = result;

                } else {
                    process(level+1);
                }
                loop[level] = loop[level] + 1;
                if (loop[level] >= d.sides) {
                    loop[level] = 0;
                }
            }
        };

        process(0);

        return results;
    }

    double chanceOfResults(Criterion criteria) {
        if (this.dice.isEmpty) {
            print("empty!");
            if (criteria.evaluate(this.extraSymbols)) {
                return 1.0;
            }
            return 0.0;
        }

        Map<Map<SymbolType, int>, int> probabilities = null;
        int sides = 1;

        for (DiceType dice in this.dice.keys) {
            int count = this.dice[dice];
            Map<Map<SymbolType, int>, int> probs = dice.getProbabilities(count: count);

            sides *= pow(dice.sides, count);

            if (probabilities == null) {
                probabilities = probs;
            } else {
                probabilities = DiceType.combineCompoundProbabilities(probabilities, probs);
            }
        }

        double chance = 0.0;

        for (Map<SymbolType, int> face in probabilities.keys) {
            Map<SymbolType, int> local = new Map<SymbolType, int>.from(face);

            for (SymbolType symbol in extraSymbols.keys) {
                int count = extraSymbols[symbol];
                if (count == 0) { continue; }

                if (!local.containsKey(symbol)) { local[symbol] = 0; }
                local[symbol] += count;

                for (SymbolType s in symbol.opposed) {
                    if (!local.containsKey(s)) { local[s] = 0; }
                    local[s] -= count;
                }

                for (SymbolType ad in symbol.additional) {
                    if (!local.containsKey(ad)) { local[ad] = 0; }
                    local[ad] += count;

                    for (SymbolType s in ad.opposed) {
                        if (!local.containsKey(s)) { local[s] = 0; }
                        local[s] -= count;
                    }
                }
            }

            if (criteria.evaluate(local)) {
                chance += probabilities[face];
            }
        }

        return chance / sides;
    }

    double chanceOfAtLeast(int count, SymbolType symbol) {
        List<DiceType> pruned = <DiceType>[];
        this.forEach((DiceType d) => pruned.add(d));
        pruned.retainWhere((DiceType d) => d.getProbabilitiesSingle(symbol) != null);

        double chance = 0.0;

        var process;
        process = (int level, int total, double weight) {
            if (level == pruned.length) {
                if (total >= count) {
                    chance += weight;
                }
            } else {
                DiceType dice = pruned[level];

                Map<int, int> probabilities = dice.getProbabilitiesSingle(symbol);

                for (int result in probabilities.keys) {
                    double p = probabilities[result] / dice.sides;

                    process(level + 1, total + result, weight * p);
                }
            }
        };

        process(0,0,1.0);

        return chance;
    }

    Map<SymbolType, double> getStats() {
        Map<SymbolType, double> stats = <SymbolType, double>{};

        for (DiceType d in this.dice.keys) {
            int count = this.dice[d];
            Map<SymbolType, double> faceStats = d.stats;

            for (SymbolType symbol in faceStats.keys) {
                double amount = faceStats[symbol] * count;

                if (!symbol.opposed.isEmpty) {
                    for (SymbolType op in symbol.opposed) {
                        if (stats.containsKey(op)) {
                            double opAmount = stats[op];
                            double diff = amount - opAmount;
                            if (diff < 0) {
                                stats[op] = stats[op] - amount;
                                amount = 0.0;
                                break;
                            } else {
                                stats.remove(op);
                                amount -= opAmount;
                            }
                        }
                    }
                }

                if (amount > 0) {
                    if (!stats.containsKey(symbol)) {
                        stats[symbol] = 0.0;
                    }
                    stats[symbol] = stats[symbol] + amount;
                }
            }
        }

        return stats;
    }

    String toString() => "Pool: $dice";

    Element createDisplayElement() {
        Element container = new DivElement()..className="dicePool";

        List<DiceType> flat = <DiceType>[];

        this.forEach((DiceType d) => flat.add(d));

        //flat.sort();

        for (DiceType d in flat) {
            //container.append(new DivElement()..className="dice${d.name}");
            container.append(d.icon.getElement());
        }

        return container;
    }
}

class DiceResult {

    List<Face> faces = <Face>[];
    Map<SymbolType, int> symbols = <SymbolType, int>{};

    void addFace(Face face) {
        faces.add(face);
        for (SymbolType symbol in face.symbols) {
            this.addSymbol(symbol);
        }
    }

    void addSymbol(SymbolType type) {
        for (SymbolType s in type.additional) {
            this.addSymbol(s);
        }

        for(SymbolType op in type.opposed) {
            if (symbols.containsKey(op)) {
                if (symbols[op] > 0) {
                    symbols[op] = symbols[op] - 1;
                    return;
                }
            }
        }

        if (!symbols.containsKey(type)) {
            symbols[type] = 0;
        }
        symbols[type] = symbols[type] + 1;
    }

    void tidy() {
        Set<SymbolType> clear = new Set<SymbolType>();
        for (SymbolType symbol in symbols.keys) {
            if (symbols[symbol] <= 0) {
                clear.add(symbol);
            }
        }

        for (SymbolType symbol in clear) {
            symbols.remove(symbol);
        }
    }
}

class DicePoolUI {
    Element element;

    Map<DiceType, NumberInputElement> _dice = <DiceType, NumberInputElement>{};
    Map<SymbolType, NumberInputElement> _symbols = <SymbolType, NumberInputElement>{};

    DicePoolUI() {
        Element ele = new DivElement();

        // Dice
        Element diceElement = new DivElement()..className="poolCategory";

        diceElement.append(new HeadingElement.h3()..text="Dice");

        Element diceInner = new DivElement();
        List<DiceType> sorted = new List<DiceType>.from(Dice.ALL_DICE)..sort();
        for (DiceType d in sorted) {
            Element e = new DivElement()..className="poolItem";

            e.append(d.icon.getElement()..title=d.name);

            NumberInputElement input = new NumberInputElement()..min="0"..valueAsNumber=0;
            _dice[d] = input;

            e.append(input);

            diceInner.append(e);
        }
        diceElement.append(diceInner);
        ele.append(diceElement);

        // Symbols
        Element symbolElement = new DivElement()..className="poolCategory";

        symbolElement.append(new HeadingElement.h3()..text="Additional Symbols");

        Element symbolInner = new DivElement();
        for (SymbolType s in Dice.ALL_SYMBOLS) {
            Element e = new DivElement()..className="poolItem";

            e.append(s.icon.getElement()..title=s.name);

            NumberInputElement input = new NumberInputElement()..min="0"..valueAsNumber=0;
            _symbols[s] = input;

            e.append(input);

            symbolInner.append(e);
        }
        symbolElement.append(symbolInner);
        ele.append(symbolElement);

        ele.append(new ButtonElement()..id="reset"..text="Reset"..onClick.listen(this.clear));

        this.element = ele;
    }

    void clear([Event e]) {
        for (NumberInputElement e in _dice.values) {
            e.valueAsNumber = 0;
        }
        for (NumberInputElement e in _symbols.values) {
            e.valueAsNumber = 0;
        }
    }

    int getDice(DiceType type) => _dice[type].valueAsNumber ?? 0;
    int getSymbol(SymbolType type) => _symbols[type].valueAsNumber ?? 0;
}