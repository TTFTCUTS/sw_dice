import "dart:html";
import "dart:svg";

import "package:CommonLib/Colours.dart";
import "package:CommonLib/Utility.dart";

abstract class Icon {
    static final defaultIcon = new LayeredTextIcon()..layer("b");
    
    Element getElement();
}

class LayeredTextIcon extends Icon {
    static final Colour _defaultColour = new Colour();
    List<Tuple<String, Colour>> _layers = <Tuple<String, Colour>>[];

    LayeredTextIcon layer(String symbol, [Colour colour]) {
        colour ??= _defaultColour;
        _layers.add(new Tuple<String,Colour>(symbol, colour));
        return this;
    }

    Element getElement() {
        Element box = new DivElement()..className="textIcon";

        Element svg = new SvgSvgElement()..setAttribute("viewBox", "0 0 100 100");

        for (int i=0; i<_layers.length; i++) {
            Tuple<String, Colour> layer = _layers[i];
            
            TextElement text = new TextElement()
                ..setAttribute("text-anchor", "middle")
                ..style.fontSize="72px"
                ..setAttribute("fill", layer.second.toStyleString())
                ..text=layer.first
                ..setAttribute("x", "50%")
                ..setAttribute("y", "72%")
            ;

            if (i != _layers.length-1) {
                text
                    ..setAttribute("stroke", layer.second.toStyleString())
                    ..setAttribute("stroke-width", "3")
                ;
            }
            
            svg.append(text);
        }
        box.append(svg);
        
        return box;
    }
}

/*class CompoundIcon extends Icon {

}*/

