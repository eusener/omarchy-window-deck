pragma ComponentBehavior: Bound
import qs.Ui
import "Model.js" as Model

BarIconButton {
    property string appId: ""
    text: Model.barGlyph(appId)
}
