# Contribuir

O runtime usa somente as dependências do Omarchy. Para os testes de desenvolvimento, são necessários Python 3, Node.js e o interpretador `lua`. Os testes visuais também exigem Quickshell e os módulos do Omarchy instalados.

O teste de composição de captura usa `qmake6`, compilador C++, `make` e os módulos de desenvolvimento e runtime QML do Qt Quick. No Ubuntu: `qt6-declarative-dev`, `qml6-module-qtquick`, `qml6-module-qtqml`, `qml6-module-qtqml-models` e `qml6-module-qtqml-workerscript`. Ele roda sem compositor, com uma textura que reproduz a importação DMA-BUF do Quickshell: pixels transparentes declarados como opacos. Isso verifica que o fundo continua sólido nos cartões de janelas Glassy, em temas claros e escuros, sem depender de capturas pessoais.

## Alterar o plugin

Edite os arquivos fonte na raiz e os catálogos em `i18n/`. Preserve o id `eusener.window-deck`, o isolamento por área/monitor e os tokens compartilhados de `qs.Commons`. Títulos de janelas são dados externos e devem permanecer em texto simples.

Depois de alterar QML, JS, Lua, backend ou traduções, gere novamente a cópia distribuída:

```bash
python3 scripts/build-runtime.py
python3 scripts/build-runtime.py --check
```

O primeiro comando cria um diretório de runtime identificado pela versão e pelo conteúdo e atualiza os caminhos no manifesto. O segundo verifica os arquivos sem modificar o projeto. Commit os fontes, o runtime gerado e o manifesto juntos. Não edite a cópia gerada à mão; componentes novos precisam ter seus arquivos incluídos no runtime.

## Verificar

```bash
python3 scripts/check-release.py
python3 -m unittest discover -s tests -v
node tests/model.test.cjs
python3 tests/run-capture-alpha.py
omarchy plugin validate .
bash tests/run-preview.sh
```

O CI executa as verificações portáteis em Python 3.12/3.14 e Node 24, com Lua 5.4, e o teste de composição Qt. A validação nativa e os demais testes de UI precisam do Omarchy. A integração de tooltip no teste JavaScript é pulada quando o shell não está instalado.

O teste offscreen não comprova o comportamento real de layer-shell, atalhos ou captura do compositor. Use também [o roteiro de desktop](docs/desktop-checklist.md). As imagens de documentação usam janelas ilustrativas para não publicar dados pessoais.

Para isolar flicker durante movimento, execute `python3 scripts/diagnose-previews.py` na sessão gráfica. Ele abre uma instância separada do seletor usando captura SHM, sem alterar o plugin instalado nem a configuração do shell. Compare com `python3 scripts/diagnose-previews.py --transport default`. Esc fecha cada instância. Essa comparação distingue problemas de transporte DMA-BUF/driver de problemas na interface; estabilidade em SHM não comprova por si só um defeito específico do driver.

## Preparar uma versão

1. Atualize a versão semântica em `manifest.json` e o `CHANGELOG.md`.
2. Gere o runtime, execute as verificações e confirme que um clone novo passa em `omarchy plugin validate`.
3. Commit e publique a branch `main`. A instalação nativa não executa scripts: os arquivos gerados precisam estar no commit.
4. Crie a tag `v<VERSÃO>` no commit verificado, caso publique uma release. O gerenciador do Omarchy atualiza pela branch padrão do repositório, não pela tag.

Contribuições devem explicar o comportamento alterado e os testes executados. Não são necessários formatos ou ferramentas adicionais para mudanças pequenas.
