const core = require('@actions/core');
const exec = require('@actions/exec');
const tc = require('@actions/tool-cache');
const axios = require('axios');
const os = require('os');

async function run() {
  try {
    // Get inputs from environment variables
    const scanId = process.env.INPUT_SCAN_ID;
    const denatUrl = process.env.INPUT_DENAT_URL;
    const pseUrl = process.env.INPUT_PSE_URL;

    console.log('Starting setup...');
    
    // Download tools
    console.log('Downloading denat tool...');
    await exec.exec('wget', ['-O', '/denat', denatUrl]);
    await exec.exec('chmod', ['+x', '/denat']);
    
    console.log('Downloading PSE tool...');
    await exec.exec('wget', ['-O', '/pse', pseUrl]);
    await exec.exec('chmod', ['+x', '/pse']);

    // Get container IP
    const networkInterfaces = os.networkInterfaces();
    const eth0Interface = networkInterfaces['eth0'];
    const containerIp = eth0Interface[0].address;
    console.log(`Container IP: ${containerIp}`);

    // Start denat
    console.log('Starting denat...');
    const denatProcess = exec.exec('./denat', [
      `-dfproxy=${containerIp}:12345`,
      '-dfports=80,443'
    ], { cwd: '/' });

    // Start PSE proxy
    console.log('Starting PSE proxy...');
    const pseProcess = exec.exec('./pse', [
      'serve',
      '--certsetup'
    ], { cwd: '/' });

    // Prepare start request
    const baseUrl = 'https://github.com';
    const repo = process.env.GITHUB_REPOSITORY;
    const buildUrl = `${baseUrl}/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}/attempts/${process.env.GITHUB_RUN_ATTEMPT}`;

    const startParams = new URLSearchParams({
      'builder': 'github',
      'id': scanId,
      'build_id': process.env.GITHUB_RUN_ID,
      'build_url': buildUrl,
      'project': process.env.GITHUB_REPOSITORY,
      'workflow': `${process.env.GITHUB_WORKFLOW} - ${process.env.GITHUB_JOB}`,
      'builder_url': baseUrl,
      'scm': 'git',
      'scm_commit': process.env.GITHUB_SHA,
      'scm_branch': process.env.GITHUB_REF_NAME,
      'scm_origin': `${baseUrl}/${repo}`
    });

    // Send start request
    console.log('Sending start request...');
    await axios.post('https://pse.invisirisk.com/start', startParams.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // Save process IDs for cleanup
    core.saveState('denat-pid', denatProcess.pid);
    core.saveState('pse-pid', pseProcess.pid);
    console.log('Setup completed successfully');

  } catch (error) {
    core.setFailed(error.message);
    console.error('Error:', error);
  }
}

async function cleanup() {
  try {
    console.log('Starting cleanup...');
    // Send end request
    const baseUrl = 'https://github.com';
    const repo = process.env.GITHUB_REPOSITORY;
    const buildUrl = `${baseUrl}/${repo}/actions/runs/${process.env.GITHUB_RUN_ID}/attempts/${process.env.GITHUB_RUN_ATTEMPT}`;

    const endParams = new URLSearchParams({
      'build_url': buildUrl,
      'status': process.env.GITHUB_RUN_RESULT
    });

    await axios.post('https://pse.invisirisk.com/end', endParams.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // Kill processes
    const denatPid = core.getState('denat-pid');
    const psePid = core.getState('pse-pid');
    
    if (denatPid) {
      await exec.exec('kill', [denatPid]);
    }
    if (psePid) {
      await exec.exec('kill', [psePid]);
    }
    
    console.log('Cleanup completed successfully');
  } catch (error) {
    core.setFailed(error.message);
    console.error('Cleanup error:', error);
  }
}

// Register cleanup to run on action complete
if (process.env.STATE_isPost === 'true') {
  cleanup();
} else {
  run();
}
