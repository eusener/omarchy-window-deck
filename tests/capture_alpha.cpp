#include <QGuiApplication>
#include <QPainter>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickPaintedItem>
#include <QQuickView>
#include <QTimer>
#include <cstdio>

// A compositor export with real alpha bytes but opaque texture metadata.
// This reproduces Quickshell's native DMA-BUF import without a live compositor.
class ExportTexture : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QObject* captureSource MEMBER source NOTIFY captureSourceChanged)
    Q_PROPERTY(bool hasContent READ hasContent CONSTANT)
    Q_PROPERTY(QSize sourceSize MEMBER size NOTIFY sourceSizeChanged)
    Q_PROPERTY(QSizeF constraintSize MEMBER constraint)
    Q_PROPERTY(bool live MEMBER live)
    Q_PROPERTY(bool paintCursor MEMBER cursor)
public:
    ExportTexture(QQuickItem* parent = nullptr) : QQuickPaintedItem(parent) {
        setFillColor(Qt::transparent);
        setOpaquePainting(true);
    }
    bool hasContent() const { return true; }
    void paint(QPainter* painter) override {
        painter->fillRect(boundingRect(), fill);
    }
    QObject* source = nullptr;
    QSize size{200, 100};
    QSizeF constraint;
    bool live = true;
    bool cursor = false;
    QColor fill{80, 40, 20, 166};
signals:
    void captureSourceChanged();
    void sourceSizeChanged();
};

int main(int argc, char** argv) {
    if (argc != 3) return 2;
    QGuiApplication app(argc, argv);
    QQuickWindow::setGraphicsApi(QSGRendererInterface::Software);
    qmlRegisterType<ExportTexture>("Quickshell.Wayland", 0, 0, "ScreencopyView");
    QQuickView view;
    view.engine()->addImportPath(QString::fromLocal8Bit(argv[2]));
    view.setColor(Qt::transparent);
    QQmlComponent component(view.engine());
    const auto url = QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1]) + "/WindowCapture.qml");
    component.loadUrl(url);
    if (component.isError()) {
        std::fprintf(stderr, "%s\n", qPrintable(component.errorString()));
        return 2;
    }
    QQmlComponent surface(view.engine());
    surface.setData("import QtQuick\nRectangle { width: 300; height: 200; color: '#202020' }", QUrl());
    auto* root = qobject_cast<QQuickItem*>(surface.create());
    if (!root) return 2;
    view.setContent(QUrl(), nullptr, root);
    auto* capture = qobject_cast<ExportTexture*>(component.createWithInitialProperties({{"parent", QVariant::fromValue(root)}}));
    if (!root || !capture) return 2;
    capture->setParent(root);
    capture->setParentItem(root);
    view.show();

    int phase = 0;
    auto* timer = new QTimer(&view);
    QObject::connect(timer, &QTimer::timeout, [&] {
        const auto image = view.grabWindow();
        const auto pixel = image.pixelColor(150, 100);
        // Hand-computed premultiplied source-over results for alpha 166/255.
        const QColor expected = phase == 1 ? QColor(130, 104, 91) : phase == 2 ? QColor(80, 40, 20) : QColor(63, 37, 24);
        const bool opaque = pixel.alpha() == 255;
        const bool matches = qAbs(pixel.red() - expected.red()) <= 1
            && qAbs(pixel.green() - expected.green()) <= 1
            && qAbs(pixel.blue() - expected.blue()) <= 1;
        const bool landscape = phase < 3;
        const bool aspect = qAbs(capture->width() - (landscape ? 300 : 100)) < 0.1
            && qAbs(capture->height() - (landscape ? 150 : 200)) < 0.1;
        if (!opaque || !matches || !aspect) {
            std::fprintf(stderr, "CAPTURE_FAILED phase=%d pixel=%d,%d,%d,%d size=%.1fx%.1f\n",
                phase, pixel.red(), pixel.green(), pixel.blue(), pixel.alpha(), capture->width(), capture->height());
            app.exit(1);
            return;
        }
        if (++phase == 4) {
            std::fprintf(stderr, "CAPTURE_ALPHA_PASSED: transparent export, light/dark themes, opaque export, portrait aspect\n");
            app.quit();
        } else if (phase == 1) {
            root->setProperty("color", QColor(224, 224, 224));
        } else if (phase == 2) {
            capture->fill.setAlpha(255);
            capture->update();
        } else {
            root->setProperty("color", QColor(32, 32, 32));
            capture->fill.setAlpha(166);
            capture->size = QSize(100, 200);
            emit capture->sourceSizeChanged();
            capture->update();
        }
    });
    timer->start(100);
    QTimer::singleShot(5000, [&] { app.exit(3); });
    return app.exec();
}

#include "capture_alpha.moc"
