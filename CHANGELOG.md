# Changelog

## 1.3.1

- Super+Ctrl+M restaura primeiro o tamanho anterior da janela ativa maximizada. Quando ela não está maximizada, continua trazendo a minimizada mais recente da área atual.

## 1.3.0

- Super+Ctrl+M restaura a minimizada mais recente no histórico de foco da área ativa, com validação da área e da origem dentro do compositor.
- Super+Ctrl+Shift+M maximiza a janela ativa usando o modo nativo do Omarchy.
- Instalador local atualiza os atalhos gerenciados; Super+M continua minimizando.

## 1.2.1

- Corrige a sobreposição do desktop nas miniaturas de janelas transparentes, como terminais com Glassy, forçando a composição alfa sobre o fundo do cartão.
- Teste de renderização reproduz o defeito de textura exportada com metadados opacos e pixels transparentes, em temas claros e escuros.

## 1.2.0

- Distribuição pronta para `omarchy plugin add`, com manifesto na raiz e runtime gerado incluído no Git.
- Atualização e remoção pelo gerenciador do Omarchy, sem hooks de instalação.
- Componentes QML em caminhos identificados por conteúdo para evitar cache de versões anteriores.
- Instalador local impede substituição de checkouts Git.
- Ícones monocromáticos nativos e cores e fontes do tema ativo.
- Minimização por área, restauração validada dentro do compositor e seletor de janelas com captura em memória.
- Documentação portátil de atalhos, migração, dependências e limites de captura.
- Validação de publicação e CI para os testes Python e JavaScript.
