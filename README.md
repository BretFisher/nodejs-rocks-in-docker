# Node.js Rocks in Docker

> My DockerCon 2022 Talk, which is an update of my [DockerCon 2019 talk](https://www.youtube.com/watch?v=Zgx0o8QjJk4) "Node.js Rocks in Docker and DevOps"

Two options: Watch [the video below](https://www.youtube.com/watch?v=Z0lpNSC1KbM) (28 minutes) or read the details in this README. They complement each other.

[![On YouTube: Node.js Rocks in Docker](https://img.youtube.com/vi/Z0lpNSC1KbM/0.jpg)](https://www.youtube.com/watch?v=Z0lpNSC1KbM)

**Want more? [Get my Docker Mastery for Node.js course with a coupon](https://www.bretfisher.com/docker-mastery-for-nodejs/): 9 hours of video to help a Node.js developer use all the best Docker features.**

Also, here's [my other example repositories](https://github.com/bretfisher/bretfisher) including DevOps automation, Docker, and Kubernetes stuff.

## Who is this for?<!-- omit in toc -->

- **You know some Node.js**
- **You know some Docker**
- **You want more Node+Docker awesomesauce**
  
## Table of Contents<!-- omit in toc -->

- [Searching for the best Node.js base image](#searching-for-the-best-nodejs-base-image)
  - [TL;DR](#tldr)
  - [General goals of a Node.js image](#general-goals-of-a-nodejs-image)
  - [Node.js base image comparison stats, September 25th, 2023](#nodejs-base-image-comparison-stats-september-25th-2023)
  - [My recommended (v18)](#my-recommended-v18)
  - [Comparison highlights](#comparison-highlights)
  - [Ruling out Alpine](#ruling-out-alpine)
  - [Ruling out `node:latest` or `node:lts`](#ruling-out-nodelatest-or-nodelts)
  - [Ruling out `debian:*-slim` as a custom base](#ruling-out-debian-slim-as-a-custom-base)
  - [Building a custom Node.js image based on Ubuntu](#building-a-custom-nodejs-image-based-on-ubuntu)
    - [Ruling out NodeSource deb packages](#ruling-out-nodesource-deb-packages)
  - [👉 My favorite custom Node.js base image](#-my-favorite-custom-nodejs-base-image)
  - [Using distroless](#using-distroless)
  - [The better distroless setup?](#the-better-distroless-setup)
- [Dockerfile best practices for Node.js](#dockerfile-best-practices-for-nodejs)
  - [You've got a `.dockerignore` right?](#youve-got-a-dockerignore-right)
  - [Use `npm ci --only=production` first, then layer dev/test on top](#use-npm-ci---onlyproduction-first-then-layer-devtest-on-top)
  - [Change user to `USER node`](#change-user-to-user-node)
  - [Proper Node.js startup: `tini`](#proper-nodejs-startup-tini)
  - [Avoid `node` process managers (npm, yarn, nodemon, forever, pm2)](#avoid-node-process-managers-npm-yarn-nodemon-forever-pm2)
  - [Add Multi-Stage For a Single Dev-Test-Prod Dockerfile](#add-multi-stage-for-a-single-dev-test-prod-dockerfile)
  - [Adding test, lint, and auditing stages](#adding-test-lint-and-auditing-stages)
- [Add multi-architecture builds](#add-multi-architecture-builds)
- [Proper Node.js shutdown](#proper-nodejs-shutdown)
- [Compose v2 and easy local workflows](#compose-v2-and-easy-local-workflows)
  - [`target: dev`](#target-dev)
  - [Dependency startup utopia: Use `depends_on:`, with `condition: service_healthy`](#dependency-startup-utopia-use-depends_on-with-condition-service_healthy)
  - [Node.js development in a container or not?](#nodejs-development-in-a-container-or-not)
- [Production Checklist](#production-checklist)

## Searching for the best Node.js base image

Honestly, this is one of the hardest choices you'll make at first. After supporting Node.js on VMs (and now images) for over a decade, I can say there is no perfect solution. Everything is a compromise. Often you'll be trading simplicy for increased flexibility, security, or smaller images. The farther down the rabit hole I go of "the smallest, most secure, most reliable Node.js image", the stranger the setup seems to get. I do have a recommended setup though, but to convince you, I need to explain how we get there.

### TL;DR

Below I list all the data and justification for my recommendations, but if you just want the result, then:

- General dev/test/prod image that's easy to use: `node:16-bullseye-slim`
- Better image that has less CVE's, build your own base with `ubuntu:20.04` and Node install (official build, image COPY, or deb package)
- Tiny prod image that's using a supported Node.js build: `gcr.io/distroless/nodejs:16`

### General goals of a Node.js image

My goals/requirements, in order of priority, for the final production stage image:

- [Tier 1](https://github.com/nodejs/node/blob/master/BUILDING.md#platform-list) support by the Node.js team.
- Minimal CVEs. No HIGH or CRITICAL vulnerabilities.
- Version (even to patch level) is controlled, to ensure reproducable builds/tests.
- Doesn't contain unneeded packages, like Python or build tools.
- Under 200MB image size (without code or node_modules).

### Node.js base image comparison stats, September 25th, 2023

Here's a compairison of the resonable options I've come up with. Most I've tried in real workloads at some point. Some are shown as base images without Node.js just so you can see their CVE count and realize they're a non-starter. Others are a combo of a base image with Node.js installed (in various ways). Lastly, remember that in multi-stage setups, we can always have one base for dev/build/test environments and another for production.

- CVE counts are crit/high/med/low.
- Docker Hub Official `node:18`, `20`, and `slim` tags are based on Debian 12 (bookworm).
- Node versions are generally `20.7.0` or `18.18.0`.

| Image Name                                 | Snyk CVEs | Docker Scout CVEs | Trivy CVEs   | Grype CVEs  | Image Size |
| ------------------------------------------ | --------- | ----------------- | ------------ | ----------- | ---------- |
| `node:18` (lts)                            | 0/0/2/159 | 0/0/3/82          | 3/58/215/468 | 3/57/198/30 | 1,042MB    |
| `node:18-slim`                             | 0/0/1/31  | 0/0/0/17          | 0/3/7/50     | 0/3/5/3     | 264MB      |
| `node:18-alpine` [^1]                      | 0/0/0/0   | 0/0/0/0           | 0/0/0/0      | 0/0/0/0     | 175MB      |
| `debian:12` (NO node)                      | 0/0/1/31  | 0/0/0/17          | 0/3/7/50     | 0/3/5/3     | 139MB      |
| `debian:12-slim` (NO node)                 | 0/0/1/31  | 0/0/0/17          | 0/3/7/50     | 0/3/5/3     | 97MB       |
| `ubuntu:22.04` (NO node)                   | 0/0/3/11  | 0/0/2/9           | 0/0/6/15     | 0/0/6/12    | 69MB       |
| `ubuntu:22.04+nodesource18` (apt pkg)      | 0/2/25/23 | 0/3/25/22         | 0/3/32/39    | 0/3/32/35   | 263MB      |
| `ubuntu:22.04+node:18` (img copy)          | 0/0/3/11  | 0/0/2/9           | 0/0/6/15     | 0/0/6/12    | 225MB      |
| `ubuntu:23.04+node:18` (img copy)          | 0/0/2/6   | 0/0/0/0           | 0/0/3/12     | 0/0/3/6     | 248MB      |
| `gcr.io/distroless/nodejs18-debian12` [^2] | 0/0/2/15  | 0/0/0/0 [^3]      | 0/1/8/12     | 0/1/8/0     | 178MB      |
| `cgr.dev/chainguard/node:latest` [^4]      | 0/0/0/0   | 0/0/0/0           | 0/0/0/0      | 0/0/0/0     | 108MB      |

[^1]: 1. Alpine's [musl libc](https://musl.libc.org/) is only Experimant support by the Node.js project, and I only recommend Tier 1 support for production servers. 2. While Alpine-based images have image tags for versioning, apk packages you need inside them can't be relelablly versioned over time (eventually packages are pulled from Alpine's apk and builds will fail.)

[^2]: 1. Distroless Node.js versions weren't always up to date. 2. Distroless can only be pinned (in image tag) to the major Node.js version. That is disapointing. You can technically use the sha256 hash of any image to pin for determinstic builds, but the process for doing so (and determining what hashes are which verions later) is far from ideal. 3. It also doesn't have a package manager and can only be the last stage in build.

[^3]: Docker is aware that Scout is not scanning distroless correctly.

[v4]: Chainguard `latest` tag is the lts version. Chainguard public images don't let you pin to version tags, so pin to the sha hash to stay determinstic. Chainguard has [paid plans that give access to version tags](https://www.chainguard.dev/unchained/important-updates-for-chainguard-images-public-catalog-users).

### My recommended (v18)
| Image Name                                 | Snyk CVEs | Docker Scout CVEs | Trivy CVEs   | Grype CVEs  | Image Size |
| ------------------------------------------ | --------- | ----------------- | ------------ | ----------- | ---------- |
| `node:18-slim`                             | 0/0/1/31  | 0/0/0/17          | 0/3/7/50     | 0/3/5/3     | 264MB      |
| `ubuntu:23.04+node:18` (img copy)          | 0/0/2/6   | 0/0/0/0           | 0/0/3/12     | 0/0/3/6     | 248MB      |
| `cgr.dev/chainguard/node:latest`           | 0/0/0/0   | 0/0/0/0           | 0/0/0/0      | 0/0/0/0     | 108MB      |

### Comparison highlights

- While Alpine isn't showing CVEs, it's not the smallest image, nor is it a supported [Tier 1](https://github.com/nodejs/node/blob/master/BUILDING.md#platform-list) build by the Node.js team. **Those are just a few of the reasons I don't recommend Alpine-based Node.js images** (see next heading below).
- Note my use of `node:16-bullseye-slim`. Then notice the better CVE count of it vs. `node:16-slim`. **Node.js Debian images don't change the Debian version after a major Node version is released.** If you want to combine the latest Node.js LTS with the current Debian stable, you'll need to use a different tag. In this example, Debian 11 (bullseye) is newer than the default `node:16` Debian 10 (buster) release. Why isn't Debian updated? For stability of that Node.js major version. Once you start using a specific Node.js major release (say 16.x), you can expect the underlying Debian major version to not change for any future Node.js 16.x release of official images. Once Debian 11 (bullseye) came out, you would have to change your image tag to specify that Debian version if you wanted to change the Debian base during a Node.js major release cycle. Changing the underlying Debian version to a new major release may cause major apt package changes.
- **Ubuntu is historially better at reducing CVEs in images than Debian.** You'll notice lower CVE counts in Ubuntu-based images. It's my go to default base for [JIT-based](https://en.wikipedia.org/wiki/Just-in-time_compilation) programming languages (Node.js, Python, Ruby, etc.)
- Google's [Distroless image](https://github.com/GoogleContainerTools/distroless) only has 1% of the file count compared to the others, yet it still similar CVE numbers to Ubuntu, and only saves 60MB in size. **Is distroless really worth the added complexity?**
- CVE counts are a moving target, so I don't make long-term image decisions base on a small CVE count difference (under 10), but we see a trend here. The High+Critical count are the most important, and these images options tend to have under twenty, or the other side of the spectrium, **hundreds**. You can't reason with hundreds. It's a non-starter. It's very rare that anyone's going to analize that many and determine your true risk. With under twenty, someone can evaluate each for the "true risk" in that use case (e.g. is the vunerable file even executied). Anything that's "zero CVEs" today won't always be zero.

### Ruling out Alpine

I'm a fan of the *idea* of Alpine images, but for Node.js, they have several fatal flaws. Alpine image variants are based on [busybox](https://hub.docker.com/_/busybox) and [musl libc](https://musl.libc.org/), which are security focused, but have side affects. The official Alpine-based Node.js image `node:alpine` has multiple non-starters for me:

- Musl libc is only considered [Expiremental by Node.js](https://github.com/nodejs/node/blob/master/BUILDING.md#platform-list).
- Alpine package versions can't be **relilablity** pinned at the minor or patch level. You can pin the image tag, but if you pin apk packages inside it, eventually it'll fail to build once the apk system updates the package version.
- The justification of using Alpine for the sake of image size is over-hyped, and app dependencies are usually far bigger then the base image size itself. I often see Node.js images with 500-800MB of `node_modules` and rendered frontend content. Many other base image options (`node:slim`, `ubuntu`, and distroless) have nearly the same size as Alpine without any of the potental negatives.
- I've personally had multiple prod issues with Alpine that didn't exist in debian-based containers, including file I/O and performance issues. Many others have told me the same over the years and for Node.js (and Python) apps. Prod teams get burned too many times to consider Alpine a safe alternative.

Sorry Alpine fans. It's still a great OS and I still use the `alpine` official image regurarly for utilites and troubleshooting.

### Ruling out `node:latest` or `node:lts`

It's convient to use the standard official images. However, these non-slim variants were foused on ease of use for new Docker users, and are not as good for production. They include a ton of packages that you'll likely never need in production, like imagemagick, compilers, mysql client, even svn/mercurial. That's why they have dozens of high and critical CVE's. That's a non-starter for production.

Here's another argument against them that I see with existing (brownfield) apps that are migrated to Docker-based builds:

> ⚠️ If you start on these non-slim official node images, you may not realize the *true* dependencies of your app, because it turns out you needed more then just the nodejs package, and if you ever switch to a different base image or package manager, you'll find that your app doesn't work, because it needed some apt/yum package that was in the bloated default base images, but aren't included in in slim/alpine/distroless images.

You might think "who doesn't know their exact system depdenencies?". With 10-year old apps, I see it often that teams don't have a true list of everything they need. They might know that on CentOS 7.3 they need x/y/z, but if they swap to a different base, it turns out there was a library included in CentOS for convicene that isn't in that new base.

Docker slim images really help ensure you have an accurate list of apt/yum dependencies.

### Ruling out `debian:*-slim` as a custom base

`debian:12-slim` saves 44MB and 2k files, but **Debian slim has the same CVE count as the default `debian:latest` image**. Too bad.

### Building a custom Node.js image based on Ubuntu

The `ubuntu:22.04` image is a great, low-CVE, small image.  I know multiple teams that use it as their base for *everything*, and make their own custom base images on top of it.

How you get Node.js into that image is the subject of this debate. You can't just `apt update && apt install nodejs`, because you'll get a wickedly old version (v12 at last check). Here's two other ways to install Node.js in Ubuntu's base image.

#### Ruling out NodeSource deb packages

NodeSource provides the official Debian (apt) packages, but they have issues and limitations, which is ultmiatly why I don't use them often for custom built node base images.

1. The package repositories drop off old versions, so you can't pin a Node.js version. A workaround is to manually download the .deb file and "pin" to its URL. This isn't a big deal, but it is a downside to adoption. People either have to discover this through trial and error, or are already apt-pros.
2. It requires Python3 to isntall Node.js. Um, what?  Yes. Every time you use a NodeSource apt package, you are adding Python 3.x minimal and any potential CVEs that come with them. I've figured out it's 20MB of additional stuff.

### 👉 My favorite custom Node.js base image

I didn't want to do this. I prefer easy. I prefer someone *else* maintain my Node.js base image, but here we are. The other options aren't great and given that this has worked so well for me, I'm now recommending and using this with others.  Tell me what you think in this GitHub repositories Discussions tab, on [Twitter](https://twitter.com/bretfisher), or in my [DevOps Discord Server](https://devops.fan).

> to get one of the smallest images, with the least CVEs, and a shell + package manager included: Use a stock ubuntu LTS image, and `COPY` in the Node.js binaries and libraries from the official Node.js slim image.

It basically looks like this, with a full example in [./dockerfiles/ubuntu-copy.Dockerfile](./dockerfiles/ubuntu-copy.Dockerfile):

```Dockerfile
FROM node:16.14.2-bullseye-slim as node
FROM ubuntu:focal-20220404 as base
COPY --from=node /usr/local/ /usr/local/
# this ensures we fix simlinks for npx, Yarn, and PnPm
RUN corepack disable && corepack enable
ENTRYPOINT ["/usr/local/bin/node"]
# rest of your stuff goes here
```

Note, if you don't like this COPY method, and feel it's a bit hacky, you could also just download the Node.js distros from nodejs.org and copy the binaries and libraries into your image. This is what the [official Node.js slim image does](https://github.com/nodejs/docker-node/blob/6e8f32de3f620833e563e9f2b427d50055783801/16/bullseye-slim/Dockerfile), but it's a bit more complex then my example above that just copies from one official image to another.

One negative here. Most CVE scanners use package lists to determine if a image or system is vunerable. When we COPY in binaries and libraries, those aren't tracked by package systems, so they won't show up on CVE scans. The workaround is to also scan the FROM image that you COPY Node.js from.

### Using distroless

I consider this a more advanced solution, because it doesn't include a shell or any utilities like package managers. A distroless image is something you `COPY` your app directory tree into as the last Dockerfile stage. It's meant to keep the image at an absolute minimum, and has the low CVE count to match.

> **It cuts the base image file count to 1% of the others, which is amazing**, but it doesn't lesson the CVEs compared to Ubuntu and only saves us 50MB over ubuntu+node. It also isn't usable in dev or test stages because they often need a shell and package manager.

Also, and I can't believe this is an issue, but the distroless images can't easily be pinned to a specific version. It can only be pinned to the Major version, like `gcr.io/distroless/nodejs20-debian12`. So those of us who want determinatic builds, can't use the version tag. A determinstic build would mean that every component is pinned to the exact version and if we built the image two times, a month apart, that nothing should be different. Now, distroless can be determinastic if you pin the sha256 hash of the image, not the version. But each time they ship a image update, the tag is reused and there's no way to go back and see what hashes match old versions (without your own manual tracking), so this isn't good.

So, while I think the ubuntu+node solution is less secure than distroless in theory, the CVE improvement in distroless just isn't there (today) to justify this extra effort of using it. I could be convinced otherwise though, so here's how I would use it:

### The better distroless setup?

My recommended usage usage is to set `node:*-slim` everywhere execpt the final production stage, where you `COPY --chown=1000:1000 /app` to distroless... AND you also pin to the sha256 hash of your specific distroless image, then I think that's a reasonable solution. If you're tracking both images well, you can be sure that your distroless is using the same base Debian that your official `node:*-slim` image is. That's ideal, then any dev/test OS (apt) libraries will be very close or identical.

Get the full image name:id with the sha256 hash from the registry by downloading the image and inspecting it. You're looking for the `RepoDigests`, or just grep like this:

```shell
docker pull gcr.io/distroless/nodejs:16
docker inspect gcr.io/distroless/nodejs:16 | grep "gcr.io/distroless/nodejs@sha256"
# or an easier way to see all image digests
docker images --digests
```

Then add it to your prod stage like this:

```Dockerfile
FROM gcr.io/distroless/nodejs20-debian12:latest@sha256:6499c05db574451eeddda4d3ddb374ac1aba412d6b2f5d215cc5e23c40c0e4d3 as distroless
COPY --from=source --chown=1000:1000 /app /app
COPY --from=base /usr/bin/tini /usr/bin/tini
```

Remember that since it's a new image vs prior stages, you'll need to repeat any metadata that you need, including ENVs, ARGs, LABEL, EXPOSE, ENTRYPOINT, CMD, WORKDIR, or USER that you set in previous stages.

A full example of using Distroless is here: [./dockerfiles/distroless.Dockerfile](./dockerfiles/distroless.Dockerfile)

## Dockerfile best practices for Node.js

These are "better" practices really, I'll let you decide if they are "best" for you.

### You've got a `.dockerignore` right?

If so it should have at least `.git` and `node_modules` in it, to avoid unnecessary files in your image.

### Use `npm ci --only=production` first, then layer dev/test on top

In the `base` stage above, you'll want to copy in your package files and then only install production dependencies. Use npm's `ci` command that will only reference the lock file for which exact versions to install. Apparently it's faster than `npm install`.

Then you'll install `devDependencies` in a future stage, but `ci` doesn't support dev-only dependency install, so you'll need to use `npm install` in the `dev` stage.

### Change user to `USER node`

There's (almost) no reason to run as root in a Node.js container. The offical node images already have this user created in the base image, so to switch your user in the Dockerfile, use the `USER node` directive.

You'll likely need more then that though. You'll want all files you copy in, and the directory you use `WORKDIR` in, to be owned by `node`.

This smallest Dockerfile would have lines in it like this, for setting directory permissions, setting file permissions during any `COPY` commands, etc:

```Dockerfile
RUN mkdir /app && chown -R node:node /app
WORKDIR /app
USER node
COPY --chown=node:node package*.json yarn*.lock ./
RUN npm ci --only=production && npm cache clean --force
COPY --chown=node:node . .
```

ProTip: If you need to run commands/shells in the container as root, add `--user=root` to your Docker commands.

### Proper Node.js startup: `tini`

When I'm writing production-quality Dockerfiles for programming languages, I usually add `tini` to the ENTRYPOINT. The [tini project](https://github.com/krallin/tini) is a simple, lightweight, and portable init process that can be used to start a Node.js process, and more importantly, it properly handles Linux Kernel signals, and reaps any [zombie processes](https://en.wikipedia.org/wiki/Zombie_process) that get lost in the suffle.

See *Proper Node.js shutdown* below for the other half of this process up/down problem.

### Avoid `node` process managers (npm, yarn, nodemon, forever, pm2)

`yarn`, `npm`, `nodemon`, `forever`, or `pm2` are not needed for launching the `node` binary.

- They add unnecessary complexity.
- They often don't listen for Linux signals (`tini` can help, but still.
- We don't want an external process launching multiple `node` processes, that's what docker/containerd/cri-o are for. If you need more replicas, use your orchestrator to launch more containers.

### Add Multi-Stage For a Single Dev-Test-Prod Dockerfile

The way I approach JIT complied languages like Node.js is to have a single Dockerfile that is used for dev, test, and prod. This is a good way to keep your production images small and still have access to that "fat" dev and test image. However, it means that the single Dockerfile will get more complex.

General Dockerfile flow of stages:

1. base: all prod dependencies, no code yet
2. dev, from base: all dev dependencies, no code yet (in dev, source code is bind-mounted anyway)
3. source, from base: add code
4. test/audit, from source: then `COPY --from=dev` for dev dependencies, then run tests. Optionally, audit and lint code (if you don't do it on git push already).
5. prod, from source: no change from source stage, but listed last so in case a stage isn't targeted, the builder will default to this stage

`--target dev` for local development where you bind-mount into the container
`--target test` for automated CI testing, like unit tests and npm audit
`--target prod` for running on servers, with no devDependencies included, and no "uninstalls" or removing things to slim down

Note, if you're using a special prod image like distroless, the `prod` stage is where you COPY in your app from the `source` stage.

### Adding test, lint, and auditing stages

In my [DockerCon 2019 version](https://www.youtube.com/watch?v=Zgx0o8QjJk4) of this talk, I showed off even more stages for running `npm test`, `npm lint`, `npm audit` and more. I no longer recommend this "inside the build" method, but it's still possible. It just depends on if you already have an automation platform.

> I don't recommend running tests/lint/audit *inside* the docker build because we have better automation platforms that are easier to troubleshoot, have better logging, and likely already have tools to test/lint/audit built-in.

I'm a big GitHub Actions fan (checkout [my GHA templates here](https://github.com/BretFisher/github-actions-templates)) and now use Super-Linter, Trivy/Snyk CVE scanners, and more in their own jobs, *after* the image is built. If you've got your own automation platform (CI/CD) then I think that's a better place to perform these tasks.

I also find that I can parallelize those things much easier in CI/CD automation rather than in a really long Dockerfile.

## Add multi-architecture builds

Now that Apple M1's are mainstream, and Windows arm64 laptops are catching up, it's the perfect time for you to build not just x86_64 (amd64) images, but also build arm64/v8 as well, at the same time.

With Docker Desktop, you can build and push multiple architectures at once.

```shell
# if you haven't created a new custom builder instance, run this once:
docker buildx create --use

# now build and push an image for two architectures:
docker buildx build -f dockerfile/5.Dockerfile --target prod --name <account/repo>:latest --platform=linux/amd64,linux/arm64 .
```

A better way is to build in automation on every pull request push, and every push to a release branch. Docker has a [GitHub Action that's great for this](https://github.com/marketplace/actions/build-and-push-docker-images).  **[You can also watch my talk on GitHub Actions for Docker CI/CD Workflows in that repository](https://github.com/BretFisher/allhands22)**.

## Proper Node.js shutdown

This topic deserves more importance, as many tend to assume it'll all work out when you're doing production rolling updates.

But, can you be sure that, once your container runtime has ask the container to stop, that:

- DB transactions are complete.
- Any long-running functions are complete, like file upload/download, loops, PDF generation, etc.
- Long-polling connections are properly closed.
- Incoming connections have completed and *gracefully* closed (TCP FIN Packet) so they can re-connect to a new container.

> ⚠️ The more you dig into this problem, the more you may realize you're providing a poor user experience during container reboots and replacements.

The end goal is if you have two replicas of a container running with a service/LB in front of it, and gracefully shutdown one of the containers, that clients/users never notice. The container will wait for processing to complete (including long-polling, file upload/download, etc.) and only then will it shut down.

Also note that Docker & Kubernetes can get in the way if not configured in the runtime config. Within 15-30s, both will kill the container unless you override that default. Some may even need *60 minutes* as a grace peroid.

`docker run --stop-timeout` in seconds

In Kubernetes, look for `terminationGracePeriodSeconds`

Projects like [http-terminator](https://github.com/gajus/http-terminator) can help you solve this.

## Compose v2 and easy local workflows

I don't always develop *in* a container, but I always start my dependencies in them. My prefered way to do that is in the `docker compose` CLI.

> Notice I didn't say `docker-compose` (with the dash). That's now "old school" v1 CLI. Docker rewrote the Compose CLI in [golang](https://go.dev/) and made it a proper Docker plug-in. [See more](https://github.com/docker/compose#readme).

Remember `version: 3.9` or `version: 2.7`?  Delete it. You no longer need a version line in your compose files (since 2020 at least) and the Compose CLI now uses the Compose Spec, which is version-less, and our Compose CLI supports all the 2.x and 3.x features in the same file!

Checkout this repoisitories [`docker-compose.yml`](./docker-compose.yml) file for these details:

### `target: dev`

Now that we have a dev stage in our Dockerfile, we need to target it for local `docker compose build`.

```yaml
services:
  node:
    build:
      dockerfile: dockerfiles/5.Dockerfile
      context: .
      target: dev
```

### Dependency startup utopia: Use `depends_on:`, with `condition: service_healthy`

This is a multi-step approach. First add healthchecks to any Compose service that is a dependency. You might need them for databases, backend services, or even proxies. Then, add a dependency section to your app service like so:

```yaml
depends_on:
  db:
    condition: service_healthy
```

A normal `depends_on: db` only waits for the db to *start*, not for it to be ready for connections. The internet is filled with workarounds for this problem, like "waitforit" scripts. Those aren't needed anymore.

If you set `condition: service_healthy`, docker will monitor that service until the healthcheck passes, and only then, start the primary service.

### Node.js development in a container or not?

I do both, it just depends on the project, the complexity, and if I have a similar node version installed on my host.  VS Code's [native ability to devleop inside a container](https://code.visualstudio.com/docs/remote/containers) is dope and I recommend you give it a shot!  It can use your existing Dockerfile and docker-compose.yml to more seamlessly develop in a container, and may be easier/faster than do-it-yourself setups.

## Production Checklist

Based on all the tips above. This list, in order of priority (highest pri first), is my personal checklist for Node.js apps in production (or any JIT langauge like Ruby, Python, PHP, etc.)

1. Slim base image with 0 high/crit CVEs via Trivy/Snyk/Grype scan.
2. Running as non-root user (`USER node`).
3. `npm audit` inside image during CI has 0 high/crit CVEs.
4. Only production dependencies (`npm ci --only=production`).
5. Tini init is *considered* for ENTRYPOINT *and* always used with healthchecks.
6. `npm`, `nodemon`, `forever`, or `pm2` are not used. App launches `node` directly (or via `tini`).
7. At least a basic healthcheck/liveness probe is used. `HEALTCHECK` is good for documentation as well as Docker/Compose/Swarm healthchecks.
8. The app code listens for Linux signals (`SIGTERM`, `SIGINT`) and gracefully shuts down.
9. If an HTTP-based app, use a better shutdown strategy in code to ensure connections are tracked, and closed gracefully during container/pod updates (TCP FIN, etc.)
10. Even-numbered LTS Node.js release is used [(current,active, or maintenance status)](https://nodejs.dev/en/about/releases/).
11. `.dockerignore` prevents `.git`, the host `node_modules`, and unwanted files.
12. `EXPOSE` has the listening ports shown.
13. Multi-platform builds are enabled for running on amd64 or arm64 when necessary.
