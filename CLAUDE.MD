# Finitra

- Máquina alvo: Notebook Dell Intel Core i7-4510U, 16gb ram, 256 de ssd.
- Skill: Voce como um especialista em desenvolvimento, linux e performance. 

# Requisitos

- Crie pra mim um script que configure esse notebook para rodar o Fedora 43 Workstation.
- Preciso de um ambiente fluido, produtivo e performatico. 
- Utilizo no dia a dia java, vscode, podman, firefox e as vezes STS Spring Eclipse Tool.
- Tenho transtorno de ansiedade generalizada e tambem sensibilidade ocular, se atenha a esse cenário para configurar o gnome -- workspaces fixos e organizados, nigth ligth automatico e cores que nao agridam o olho.
- O script deve funcionar como um post install para a distro nesse notebook.
- Crie usando bash script para facilitar a partir de uma instalacao do zero, e que se rodar várias vezes ele seja idempotente. 
- O script deve ser rpm-first, a preferencia é por pacotes rpm para esse notebook. Verifique o site oficial do pacote para buscar e instalar de la o rpm (vscode, atraves do import do repositorio dnf)
- Flatpak só se não tiver pacote rpm, como o Obsidian.
- Creio que o Fedora ja venha com zram por padrao, verifique por favor. 
- Use mise (https://mise.jdx.dev/) para instalar java 21, java 25, nodejs latest lts, python latest, golang latest. Coloque todas as versoes no arquivo no arquivo de config mise (~/.config/mise/config.toml) global para instalar com mise diretamente todas as versoes la.
- Instale a multimedia padrao para fedora, com os pacotes necessarios para rodar video, audio, h264, etc.
- Para o localsearch/tracker, desabilite o que for trabalho pesado para esse notebook, preciso de busca de aplicativos, calculadora, documentos basicos. Lembrando que o tracker foi substituido pelo localsearch, se atente a isso.
- Instale o starship com bash para ter um prompt melhor com foco em dev.
- Instale os pacotes padrao no sistema, zip/unzip, rar/unrar, tar, build essentials, git, curl, fzf, bat, entre outros importantes.

# Estrutura

- Se puder modularizar para facilitar a inclusao de novos pacotes no futuro e novos modulos, tipo arquivos shell tematicos para modulos, para instalar todos ou modulos separados. 
- Os pacotes RPMs coloque em um arquivo apartado (rpm-pkgs.list) para poder facilitar adicoes e remocoes sem tocar no script. 
- Crie tambem para os possiveis flatpaks-pkgs. 
- Crie tambem um arquivo (gnome-settings.list) para todas as configs gsettings para facilitar a mudanca. Nesse arquivo deve ter a chave e valor para ser aplicado por uma função gs_set utilitaria.
- Crie um arquivo de configuracoes para variaveis padrao e para que possa ser alterados facilmente tambem -- [script].config.
- Separe um arquivo utils.sh para as funcoes utilitarias e globais, para variaveis, e outras configuracoes para facil manutencao.
- Crie um menu para execução guiada de todos os modulos ou so se alguns. Tome cuidado com as precedencias.
- Não travar a dependencia no nome do arquivo, pois pode aparecer outros futuramente que precisem ser inseridos de forma intermediaria. Seja inteligente. 
- Creio que deva ter tambem um modulo obrigatorio para update do sistema e configuracoes iniciais do script.
- O menu pode ser criado simples ou utilizado algum framewok para tal no shell.

# Specs

Sistema modular e bem organizado para configurar seu Fedora 43 Workstation com foco em performance, acessibilidade visual e ambiente de desenvolvimento.
Criei um sistema completo e modular para configurar seu Fedora 43 Workstation! 🚀

## 📦 O que foi criado:

### ✅ **Sistema Modular Idempotente**
- **9 arquivos principais** organizados por função
- **5 módulos** independentes e testáveis
- **3 arquivos de dados** facilmente editáveis
- **4 documentações** completas

### 🎯 **Características Principais:**

1. **Menu Interativo Visual** - Interface amigável para execução guiada
2. **Totalmente Modular** - Execute tudo ou apenas módulos específicos
3. **Idempotente** - Rode quantas vezes quiser sem problemas
4. **Customizável** - Listas separadas para pacotes e configurações
5. **Acessibilidade** - Configurações especiais para sensibilidade ocular e ansiedade
6. **Performance** - Otimizações para i7-4510U e 16GB RAM + SSD
7. A saída do script no stdout é descritivo para saber o que esta acontecendo na execução.

### 📁 **Estrutura:**

```
fedora-setup/
├── fedora-setup.sh          ← Script principal (execute este!)
├── bootstrap.sh             ← Instalação rápida automática
├── fedora-setup-default.config      ← Todas as configurações default
├── utils.sh                 ← Funções reutilizáveis
│
├── modules/                 ← Módulos independentes
│   ├── 00-system.sh        ← Sistema base (OBRIGATÓRIO)
│   ├── 10-packages.sh      ← Pacotes RPM/Flatpak
│   ├── 20-dev-tools.sh     ← Mise, Java, Node, Python, Go
│   ├── 30-desktop.sh       ← GNOME + Acessibilidade
│   └── 40-optimizations.sh ← Performance + SSD
│
├── data/
│   ├── rpm-pkgs.list       ← Lista editável de RPMs
│   ├── flatpak-pkgs.list   ← Lista editável de Flatpaks
│   └── gnome-settings.list ← Configurações GNOME
│
└── Documentação completa em 4 arquivos
```

## 🚀 **Como Usar:**

```bash
# 1. Bootstrap
curl -fsSL https://raw.githubusercontent.com/lucasbt/fedora-setup/main/bootstrap.sh | bash
source ~/.bashrc

# 2. Executar o script principal
./fedora-setup.sh
```

- A instalação deve ser baixada em ~/.local/share/fedora-setup
- O arquivo de configuração deve ser adicionado em ~/.config/fedora-setup/fedora-setup.config

### 🎨 **Configurações para Você:**

- ✅ **Night Light** automático (3700K) para conforto ocular
- ✅ **4 Workspaces fixos** (Super+1,2,3,4) para organização
- ✅ **Tema dark** global
- ✅ **Texto 15% maior** para melhor legibilidade
- ✅ **Animações suaves** (não frenéticas)
- ✅ **Indexação limitada** do Tracker/Localsearch

### 💻 **Ambiente Dev Completo:**

- ☕ Java 21 + 25 (via Mise)
- 🟢 Node.js LTS (via Mise)
- 🐍 Python latest (via Mise)
- 🐹 Go latest (via Mise)
- 📝 VSCode (repo oficial)
- 🐳 Podman (com alias docker)
- ⭐ Starship (prompt bonito)

### ⚡ **Otimizações:**

- ZRAM ativo
- Swappiness = 10 (menos swap)
- I/O scheduler para SSD
- DNF com 10 downloads paralelos
- TRIM semanal automático
- Journald limitado

## 📚 **Documentação Incluída:**

1. **README.md** - Documentação principal completa
2. **CUSTOMIZATION.md** - Como adicionar pacotes e módulos
3. **CHECKLIST.md** - Verificações pós-instalação
4. **PROJECT-SUMMARY.md** - Visão geral técnica

