# Rallet

Rallet é um aplicativo de finanças pessoais desenvolvido pela Rotec, com foco em controle financeiro, receitas, despesas, cartões de crédito, faturas, planejamento e compreensão da situação financeira.

## Versão atual

- Rallet **1.0.0**
- Build **45**
- Flutter package: `rallet`
- Android package: `com.rotecbr.rallet`
- minSdk: **24**
- targetSdk: **36**
- SQLite schema: **17**
- Firebase oficial: `rallet-rotec`

## Dados e privacidade

Os dados financeiros são armazenados localmente no aparelho em SQLite.

O Firebase é utilizado para autenticação e dados de perfil/metadados. As finanças do usuário não dependem de sincronização com o Firestore.

No Android, o banco local é isolado por usuário autenticado.

## Backup e restauração

O Rallet permite criar e restaurar backups locais do banco de dados.

Backups de versões anteriores continuam compatíveis quando atendem ao schema suportado pelo aplicativo.

## Desenvolvimento

Requisitos principais:

- Flutter / Dart
- Android SDK
- JDK compatível com Flutter/Android

Preparação:

```bash
flutter pub get
flutter analyze
flutter test
```

Build Android:

```bash
flutter build apk
```

A chave privada utilizada para assinar os releases oficiais da Rotec não faz parte deste repositório.

## Licença

Este projeto é distribuído sob a **GNU Affero General Public License v3.0 (AGPL-3.0)**.

Consulte o arquivo `LICENSE`.

## Origem e créditos

O Rallet é uma evolução do projeto open source **Finan Master**, desenvolvido por Gabriel Hainzenreder.

Projeto original:

https://github.com/GabrielDimaa/finan_master_app

O projeto passou posteriormente por uma fase de desenvolvimento denominada **XP Finance** antes de receber a identidade definitiva **Rallet**.

Desenvolvimento e modificações do Rallet:

**Raí Miguel / Rotec**
