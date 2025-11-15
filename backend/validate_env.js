#!/usr/bin/env node
/*
  Simple startup validator for critical environment variables.
  - Loads .env (if present)
  - Verifies presence of Firebase service account or project id
  - If EMAIL_PROVIDER=emailjs then verifies EmailJS keys required to send from backend
  Exit code: 0 = ok, 1 = missing required config
*/

require('dotenv').config();

function missing(keys) {
  return keys.filter(k => !process.env[k]);
}

// Check firebase config (either a service account JSON or project id)
const hasFirebase = Boolean(process.env.FIREBASE_SERVICE_ACCOUNT || process.env.FIREBASE_PROJECT_ID);
if (!hasFirebase) {
  console.error('\n[ENV CHECK] ERRO: configurações do Firebase ausentes.');
  console.error('  Defina uma das variáveis abaixo (em segredo na sua plataforma de deploy):');
  console.error('    - FIREBASE_SERVICE_ACCOUNT (JSON do service account)');
  console.error('    - FIREBASE_PROJECT_ID');
  console.error('  Use o arquivo .env.example como referência.\n');
  process.exit(1);
}

// Provider-specific checks
const provider = (process.env.EMAIL_PROVIDER || '').toLowerCase();
if (provider === 'emailjs') {
  const required = ['EMAILJS_SERVICE_ID', 'EMAILJS_TEMPLATE_ID', 'EMAILJS_PUBLIC_KEY'];
  const miss = missing(required);
  if (miss.length) {
    console.error(`\n[ENV CHECK] ERRO: EMAIL_PROVIDER=emailjs, faltando: ${miss.join(', ')}.`);
    console.error('  Defina as variáveis necessárias como secrets na plataforma (não as coloque no cliente).\n');
    process.exit(1);
  }
}

// Warn if provider is unset
if (!provider) {
  console.warn('\n[ENV CHECK] AVISO: EMAIL_PROVIDER não definido. Se você pretende enviar e-mails do backend, configure EMAIL_PROVIDER e chaves correspondentes.');
}

console.log('\n[ENV CHECK] OK: variáveis de ambiente críticas presentes. Iniciando servidor...\n');
process.exit(0);
