import { defineConfig } from 'astro/config';

const owner = process.env.GITHUB_REPOSITORY_OWNER ?? 'localhost';
const repo = process.env.GITHUB_REPOSITORY?.split('/')[1] ?? '';
const isGithubPages = process.env.GITHUB_ACTIONS === 'true';
const isUserPagesSite = repo && repo.toLowerCase() === `${owner.toLowerCase()}.github.io`;

export default defineConfig({
  site: isGithubPages ? `https://${owner}.github.io` : 'http://localhost:4321',
  base: isGithubPages && repo && !isUserPagesSite ? `/${repo}` : '/',
});
