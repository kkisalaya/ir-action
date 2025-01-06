const core = require('@actions/core');
const exec = require('@actions/exec');
const tc = require('@actions/tool-cache');
const axios = require('axios');

async function run() {
  try {
    // Get inputs
    const scanId = core.getInput('scan_id', { required: true });
    const denatUrl = core.getInput('denat_url', { required: true });
    const pseUrl = core.getInput('pse_url', { required: true });
    const containerImage = core.getInput('container_image');

    // Download and setup container
    await exec.exec('docker', ['pull', containerImage]);
    const containerId = await getContainerIdFromOutput(
      await exec.getExecOutput('docker', ['run', '-d', containerImage])
    );

    // Download tools
    await exec.exec('docker', ['exec', containerId, 'wget', '-O', '/denat', denatUrl]);
    await exec.exec('docker', ['exec', containerId, 'chmod', '+x', '/denat']);
    await exec.exec('docker', ['exec', containerId, 'wget', '-O', '/pse', pseUrl]);
    await exec.exec('docker', ['exec', containerId, 'chmod', '+x', '/pse']);

    // Get container IP
    const containerIp = await getContainerIp(containerId);

    // Start denat
    await exec.exec('docker', [
      'exec',
      containerId,
      'sudo',
      './denat',
      `-dfproxy=${containerIp}:12345`,
      '-dfports=80,443'
    ]);

    // Start PSE proxy
    await exec.exec('docker', [
      'exec',
      containerId,
      'sudo',
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
    await axios.post('https://pse.invisirisk.com/start', startParams.toString(), {
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    });

    // Set container ID as output for cleanup
    core.saveState('container-id', containerId);

  } catch (error) {
    core.setFailed(error.message);
  }
}

async function cleanup() {
  try {
    const containerId = core.getState('container-id');
    if (containerId) {
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
      await exec.exec('docker', ['stop', containerId]);
      await exec.exec('docker', ['rm', containerId]);
    }
  } catch (error) {
    core.setFailed(error.message);
  }
}

async function getContainerIdFromOutput(result) {
  return result.stdout.trim();
}

async function getContainerIp(containerId) {
  const result = await exec.getExecOutput('docker', [
    'inspect',
    '-f',
    '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}',
    containerId
  ]);
  return result.stdout.trim();
}

// Register cleanup to run on action complete
if (process.env.STATE_isPost === 'true') {
  cleanup();
} else {
  run();
}
