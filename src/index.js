const core = require('@actions/core');
const exec = require('@actions/exec');
const tc = require('@actions/tool-cache');
const axios = require('axios');

async function run() {
  try {
    // Get inputs from environment variables
    const scanId = process.env.INPUT_SCAN_ID;
    const denatUrl = process.env.INPUT_DENAT_URL;
    const pseUrl = process.env.INPUT_PSE_URL;
    const containerImage = process.env.INPUT_CONTAINER_IMAGE || 'alpine:latest';

    console.log('Starting container setup...');
    
    // Download and setup container
    await exec.exec('docker', ['pull', containerImage]);
    console.log('Container image pulled successfully');
    
    const containerResult = await exec.getExecOutput('docker', ['run', '-d', containerImage]);
    const containerId = containerResult.stdout.trim();
    console.log(`Container started with ID: ${containerId}`);

    // Download tools
    console.log('Downloading denat tool...');
    await exec.exec('docker', ['exec', containerId, 'wget', '-O', '/denat', denatUrl]);
    await exec.exec('docker', ['exec', containerId, 'chmod', '+x', '/denat']);
    
    console.log('Downloading PSE tool...');
    await exec.exec('docker', ['exec', containerId, 'wget', '-O', '/pse', pseUrl]);
    await exec.exec('docker', ['exec', containerId, 'chmod', '+x', '/pse']);

    // Get container IP
    const ipResult = await exec.getExecOutput('docker', [
      'inspect',
      '-f',
      '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
      containerId
    ]);
    const containerIp = ipResult.stdout.trim();
    console.log(`Container IP: ${containerIp}`);

    // Start denat
    console.log('Starting denat...');
    await exec.exec('docker', [
      'exec',
      containerId,
      './denat',
      `-dfproxy=${containerIp}:12345`,
      '-dfports=80,443'
    ]);

    // Start PSE proxy
    console.log('Starting PSE proxy...');
    await exec.exec('docker', [
      'exec',
      containerId,
      './pse',
      'serve',
      '--certsetup'
    ]);

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

    // Set container ID as output for cleanup
    core.saveState('container-id', containerId);
    console.log('Setup completed successfully');

  } catch (error) {
    core.setFailed(error.message);
    console.error('Error:', error);
  }
}

async function cleanup() {
  try {
    const containerId = core.getState('container-id');
    if (containerId) {
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

      // Stop and remove container
      console.log('Stopping container...');
      await exec.exec('docker', ['stop', containerId]);
      await exec.exec('docker', ['rm', containerId]);
      console.log('Cleanup completed successfully');
    }
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
